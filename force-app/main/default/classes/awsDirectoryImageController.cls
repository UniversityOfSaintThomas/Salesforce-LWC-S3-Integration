/**
 * Created by Thaddaeus Dahlberg, Software Engineer, University of St. Thomas on 10/22/2024.
 */


public with sharing class awsDirectoryImageController {

    public static String getBucketLink() {
        ConnectApi.NamedCredential nc = ConnectApi.NamedCredentials.getNamedCredential('AWS_S3_Directory_Image');
        if (nc != null) {
            return nc.calloutUrl + '/';
        }
        return '/';
    }

    @AuraEnabled
    public static String findObject(String recordId, Boolean deletePrevious, String fileNameSuffix, String imageField) {
        validateRequiredParams(recordId, imageField);

        if (deletePrevious) {
            List<String> keysToDelete = findAndDeletePreviousKeys(recordId, true, fileNameSuffix);
            if (!keysToDelete.isEmpty()) {
                updateRecord(recordId, imageField, null);
            }
            return null;
        }

        return getExistingImageLink(recordId, fileNameSuffix);
    }

    /**
     * Finds keys for the given record/suffix and, when requested, deletes them from S3.
     * Performs callouts only; does not perform any DML so callers remain free to make
     * further callouts afterward without tripping "uncommitted work pending" errors.
     *
     * @param recordId The Id of the record whose associated S3 objects should be located
     * @param deletePrevious When true, deletes any located S3 objects
     * @param fileNameSuffix Optional suffix used to distinguish multiple images per record
     * @return List of S3 object keys that were found (and deleted, if requested)
     */
    private static List<String> findAndDeletePreviousKeys(String recordId, Boolean deletePrevious, String fileNameSuffix) {
        List<String> keysToDelete = listKeysForPrefix(md5fileName(recordId), fileNameSuffix);
        if (keysToDelete.isEmpty()) {
            keysToDelete = listKeysForPrefix(md5fileNameLegacy(recordId), fileNameSuffix);
        }

        if (deletePrevious && !keysToDelete.isEmpty()) {
            deleteOldFile(keysToDelete);
        }

        return keysToDelete;
    }

    /**
     * Looks up the existing image link for a record without performing any deletions.
     *
     * @param recordId The Id of the record whose S3 object should be located
     * @param fileNameSuffix Optional suffix used to distinguish multiple images per record
     * @return The full S3 URL for the located object, or null if none was found
     */
    private static String getExistingImageLink(String recordId, String fileNameSuffix) {
        List<String> keys = listKeysForPrefix(md5fileName(recordId), fileNameSuffix);
        if (keys.isEmpty()) {
            keys = listKeysForPrefix(md5fileNameLegacy(recordId), fileNameSuffix);
        }
        if (keys.isEmpty()) {
            return null;
        }
        return getBucketLink() + keys[0];
    }

    private static List<String> listKeysForPrefix(String hashedFileName, String fileNameSuffix) {
        String fileName = hashedFileName;
        if (String.isNotBlank(fileNameSuffix)) {
            fileName += fileNameSuffix;
        }
        String endPoint = '?prefix=' + EncodingUtil.urlEncode(fileName, 'UTF-8') + '.';
        HttpResponse res = awsS3Request('GET', endPoint, null, '');
        String namespace = 'http://s3.amazonaws.com/doc/2006-03-01/';
        Dom.Document doc = res.getBodyDocument();
        Dom.XmlNode root = doc.getRootElement();

        List<String> keys = new List<String>();
        for (Dom.XmlNode node : root.getChildElements()) {
            if (node.getName() == 'Contents' && node.getNamespace() == namespace) {
                keys.add(node.getChildElement('Key', namespace).getText());
            }
        }
        return keys;
    }

    @AuraEnabled
    public static String addObjectsToBucket(String fileType, String recordId, String base64FileContent, String imageField, String fileNameSuffix) {
        validateRequiredParams(recordId, imageField);
        validateFileType(fileType);
        if (String.isBlank(base64FileContent)) {
            throw new AwsS3CalloutException('No file content was provided to upload.');
        }

        String bucketLink = getBucketLink();
        String fileSuffix = fileType.replace('image/', '');
        if (fileSuffix == 'jpeg') {
            fileSuffix = 'jpg';
        }
        Blob fileBody = EncodingUtil.base64Decode(base64FileContent);

        // Delete any previous S3 object(s) for this record/suffix. Callout only -
        // the field is not cleared here so the DML below is the only write for this transaction.
        findAndDeletePreviousKeys(recordId, true, fileNameSuffix);

        String fileName = '/' + md5fileName(recordId) + fileNameSuffix + '.' + fileSuffix;
        HttpResponse res = awsS3Request('PUT', fileName, fileBody, fileType);
        String imageLink = bucketLink + fileName.removeStart('/');
        if (res.getStatusCode() == 200) {
            // DML happens last, after every callout in this transaction, to avoid
            // "You have uncommitted work pending. Please commit or rollback before calling out."
            updateRecord(recordId, imageField, imageLink);
            return imageLink + '?t=' + Datetime.now().getTime();
        }
        return '';
    }

    private static final Set<String> ALLOWED_IMAGE_TYPES = new Set<String>{
        'image/jpeg', 'image/jpg', 'image/gif', 'image/png'
    };

    /**
     * Validates that recordId and imageField were provided. Both are required for every
     * public entry point since this component can be mapped to any object/field combination.
     *
     * @param recordId The Id supplied by the caller
     * @param imageField The target field API name supplied by the caller
     */
    private static void validateRequiredParams(String recordId, String imageField) {
        if (String.isBlank(recordId)) {
            throw new AwsS3CalloutException('A record Id is required.');
        }
        if (String.isBlank(imageField)) {
            throw new AwsS3CalloutException('A target image field is required.');
        }
    }

    /**
     * Validates the uploaded file's content type against the allowed image types.
     * Client-side validation (accepted formats on the file input) can be bypassed, so this
     * server-side check is the actual enforcement boundary for public/anonymous users.
     *
     * @param fileType The MIME type reported for the uploaded file
     */
    private static void validateFileType(String fileType) {
        if (String.isBlank(fileType) || !ALLOWED_IMAGE_TYPES.contains(fileType.toLowerCase())) {
            throw new AwsS3CalloutException('Unsupported file type. Only JPG, GIF, and PNG images are allowed.');
        }
    }

    @TestVisible
    private static void updateRecord(Id recordId, String imageField, String imageLink) {
        Id myRecordId;
        Schema.SObjectType sObjectType;
        try {
            myRecordId = recordId;
            sObjectType = myRecordId.getSObjectType();
        } catch (Exception e) {
            throw new AwsS3CalloutException('The provided record Id is not valid.');
        }
        if (sObjectType == null) {
            throw new AwsS3CalloutException('The provided record Id is not valid.');
        }

        Schema.DescribeSObjectResult describeSObjectResult = sObjectType.getDescribe();
        Schema.DescribeFieldResult fieldResult = describeSObjectResult.fields.getMap().containsKey(imageField)
            ? describeSObjectResult.fields.getMap().get(imageField).getDescribe()
            : null;
        if (fieldResult == null) {
            throw new AwsS3CalloutException('The image field "' + imageField + '" does not exist on ' + describeSObjectResult.getName() + '.');
        }
        if (!fieldResult.isUpdateable()) {
            throw new AwsS3CalloutException('You do not have permission to update the image field on this record.');
        }

        SObject sObj = Database.query('SELECT Id, ' + imageField + ' FROM ' + describeSObjectResult.getName() + ' WHERE Id = :myRecordId');
        String imageLinkField = imageLink;
        if (String.isNotBlank(imageLinkField) && fieldResult.isHtmlFormatted()) {
            imageLinkField = '<img src="' + imageLinkField + '" />';
        }

        sObj.put(imageField, imageLinkField);
        update sObj;
    }

    public class AwsS3CalloutException extends Exception {
    }

    @TestVisible
    private static void deleteOldFile(List<String> keysToDelete) {
        Http http = new Http();
        for (String fileName : keysToDelete) {
            HttpRequest request = new HttpRequest();
            request.setMethod('DELETE');
            request.setEndpoint('callout:AWS_S3_Directory_Image/' + fileName);
            HttpResponse res = http.send(request);
            if (res.getStatusCode() != 204) {
                throw new AwsS3CalloutException('Failed to delete S3 object ' + fileName + ': received status ' + res.getStatusCode());
            }
        }
    }

    @TestVisible
    private static HttpResponse awsS3Request(String method, String endpoint, Blob body, String contentType) {
        HttpRequest request = new HttpRequest();
        request.setMethod(method);
        if (body != null) request.setBodyAsBlob(body);
        request.setEndpoint('callout:AWS_S3_Directory_Image' + endpoint);
        if (String.isNotBlank(contentType)) request.setHeader('Content-Type', contentType);

        HttpResponse resp = new Http().send(request);
        if (resp.getStatusCode() != 200) {
            throw new AwsS3CalloutException('AWS S3 request failed: received status ' + resp.getStatusCode());
        }
        return resp;
    }

    @TestVisible
    private static String md5fileName(String originalFilename) {
        String orgId = UserInfo.getOrganizationId();
        Blob fileNameBlob = Blob.valueOf(orgId + originalFilename + 'USTDirImage');
        Blob hasFileNameBlob = Crypto.generateDigest('MD5', fileNameBlob);
        return EncodingUtil.convertToHex(hasFileNameBlob);
    }

    // Pre-org-scoped hash. Kept so existing S3 objects uploaded before the org-scoped
    // hash was introduced can still be found, migrated, and cleaned up.
    @TestVisible
    private static String md5fileNameLegacy(String originalFilename) {
        Blob fileNameBlob = Blob.valueOf(originalFilename + 'USTDirImage');
        Blob hasFileNameBlob = Crypto.generateDigest('MD5', fileNameBlob);
        return EncodingUtil.convertToHex(hasFileNameBlob);
    }
}