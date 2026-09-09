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
        String bucketLink = getBucketLink();
        String fileName = md5fileName(recordId);
        if (String.isNotBlank(fileNameSuffix)) {
            fileName += fileNameSuffix;
        }
        String imageLink;
        String endPoint = '?prefix=' + EncodingUtil.urlEncode(fileName, 'UTF-8') + '.';
        HttpResponse res = awsS3Request('GET', endPoint, null, '');
        System.debug('header: ' + res.getHeader('Content-Type'));
        System.debug('res: ' + res.toString());
        String namespace = 'http://s3.amazonaws.com/doc/2006-03-01/';
        Dom.Document doc = res.getBodyDocument();
        Dom.XmlNode root = doc.getRootElement();
        System.debug('doc: ' + doc.toString());

        List<String> keysToDelete = new List<String>();

        for (Dom.XmlNode node : root.getChildElements()) {
            if (node.getName() == 'Contents' && node.getNamespace() == namespace) {
                String key = node.getChildElement('Key', namespace).getText();
                keysToDelete.add(key);
                imageLink = bucketLink + key;
            }
        }

        if (deletePrevious) {
            deleteOldFile(keysToDelete);
            if (!keysToDelete.isEmpty()) {
                updateRecord(recordId, imageField, null);
            }
        }

        return String.isNotBlank(imageLink) && !deletePrevious ? imageLink : null;
    }

    @AuraEnabled
    public static String addObjectsToBucket(String fileType, Id recordId, String base64FileContent, String imageField, String fileNameSuffix) {
        String bucketLink = getBucketLink();
        String fileSuffix = fileType.replace('image/', '');
        if (fileSuffix == 'jpeg') {
            fileSuffix = 'jpg';
        }
        Blob fileBody = EncodingUtil.base64Decode(base64FileContent);
        findObject(recordId, true, fileNameSuffix, imageField);
        String fileName = '/' + md5fileName(recordId) + fileNameSuffix + '.' + fileSuffix;
        HttpResponse res = awsS3Request('PUT', fileName, fileBody, fileType);
        String imageLink = bucketLink + fileName.removeStart('/');
        if (res.getStatusCode() == 200) {
            updateRecord(recordId, imageField, imageLink);
            return imageLink + '?t=' + Datetime.now().getTime();
        }
        return '';
    }

    @TestVisible
    private static void updateRecord(Id recordId, String imageField, String imageLink) {
        Id myRecordId;
        Schema.SObjectType sObjectType;
        try {
            myRecordId = recordId;
            sObjectType = myRecordId.getSObjectType();
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
        }
        if (String.isNotBlank(imageField) && sObjectType != null) {
            Schema.DescribeSObjectResult describeSObjectResult = sObjectType.getDescribe();
            Schema.DescribeFieldResult fieldResult = describeSObjectResult.fields.getMap().containsKey(imageField)
                ? describeSObjectResult.fields.getMap().get(imageField).getDescribe()
                : null;
            if (fieldResult == null) {
                System.debug('Error: field ' + imageField + ' does not exist on ' + describeSObjectResult.getName());
                return;
            }

            SObject sObj = Database.query('SELECT Id, ' + imageField + ' FROM ' + describeSObjectResult.getName() + ' WHERE Id = :myRecordId');
            String imageLinkField = imageLink;
            if (String.isNotBlank(imageLinkField) && fieldResult.isHtmlFormatted()) {
                imageLinkField = '<img src="' + imageLinkField + '" />';
            }

            sObj.put(imageField, imageLinkField);
            update sObj;
        }
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
        Blob fileNameBlob = Blob.valueOf(originalFilename + 'USTDirImage');
        Blob hasFileNameBlob = Crypto.generateDigest('MD5', fileNameBlob);
        return EncodingUtil.convertToHex(hasFileNameBlob);
    }
}