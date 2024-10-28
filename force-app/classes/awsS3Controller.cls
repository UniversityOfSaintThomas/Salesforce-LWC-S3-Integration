/**
 * Created by Thaddaeus Dahlberg, Software Engineer, University of St. Thomas on 10/22/2024.
 */


public with sharing class awsS3Controller {

    @AuraEnabled
    public static String findObject(String recordId, Boolean deletePrevious) {
        String fileName = md5fileName(recordId);
        String imageLink = 'https://stthomas-dev-salesforce-directory-images.s3.us-east-1.amazonaws.com/';


        String endPoint = '?prefix=' + EncodingUtil.urlEncode(fileName, 'UTF-8') + '.';
        HttpResponse res = awsS3Request('GET', endPoint, null, '');

        // Checkpoint
        //Assert.areEqual(200, res.getStatusCode());

        // The following section processes the XML result and formats the data for better readability.
        String namespace = 'http://s3.amazonaws.com/doc/2006-03-01/';
        Dom.Document doc = res.getBodyDocument();
        Dom.XmlNode root = doc.getRootElement();
        //String bucketName = root.getChildElement('Name', namespace).getText();

        List<String> keysToDelete = new List<String>();
        for (Dom.XmlNode node : root.getChildElements()) {
            if (node.getName() == 'Contents' && node.getNamespace() == namespace) {
                String key = node.getChildElement('Key', namespace).getText();
                System.debug('Key: ' + key);
                Datetime lastLastModified = null;
                DateTime lastModified = Datetime.valueOf(node.getChildElement('LastModified', namespace).getText().replace('T', ' ').replace('Z', ''));
                String storageClass = node.getChildElement('StorageClass', namespace).getText();
                System.debug('lastModified: ' + lastModified.toString());
                keysToDelete.add(key);
                if (lastLastModified == null) {
                    imageLink = 'https://stthomas-dev-salesforce-directory-images.s3.us-east-1.amazonaws.com/' + key;
                } else if (lastModified < lastLastModified) {
                    imageLink = 'https://stthomas-dev-salesforce-directory-images.s3.us-east-1.amazonaws.com/' + key;
                }
                lastLastModified = lastModified;
                //return 'https://stthomas-dev-salesforce-directory-images.s3.us-east-1.amazonaws.com/' + key;
            }
        }
        if (deletePrevious) {
            deleteOldFile(keysToDelete);
        }
        if (String.isNotBlank(imageLink) && !deletePrevious) {
            return imageLink;
        }
        return null;
    }


    @AuraEnabled
    public static void addObjectsToBucket(String fileName, String fileType, Id recordId, String base64FileContent) {

        // System.debug('fileName: ' + fileName);
        //System.debug('fileType: ' + fileType);
        //System.debug('recordId: ' + recordId);
        //System.debug('base64FileContent: ' + base64FileContent);

        //Get file suffix by getting last characters after last . in filename
        String fileSuffix = fileName.substringAfterLast('.');

        // Decode the Base64 content
        Blob fileBody = EncodingUtil.base64Decode(base64FileContent);

        //create an md5 hash of the recordId to use as the file name with salt
        findObject(recordId, true);
        fileName = md5fileName(recordId);
        fileName = '/' + fileName + '.' + fileSuffix;
        System.debug('fileName: ' + fileName);
        HttpResponse res = awsS3Request('PUT', fileName, fileBody, fileType);

    }

    private static void deleteOldFile(List<String> keysToDelete) {
        String deletePayload = '<Delete xmlns="http://s3.amazonaws.com/doc/2006-03-01/">';
        for (String key : keysToDelete) {
            deletePayload += '<Object><Key>' + key + '</Key></Object>';
        }
        deletePayload += '</Delete>';
        System.debug('deletePayload: ' + deletePayload);

        Blob payloadBlob = Blob.valueOf(deletePayload);
        String contentMD5 = EncodingUtil.base64Encode(Crypto.generateDigest('MD5', payloadBlob));

        HttpRequest request = new HttpRequest();
        request.setMethod('POST');
        request.setEndpoint('callout:AWS_S3?delete');
        request.setHeader('Content-Type', 'application/xml');
        request.setHeader('Content-MD5', contentMD5);
        request.setBody(deletePayload); // Convert Blob to String

        Http http = new Http();
        HttpResponse res = http.send(request);
        System.debug('res: ' + res);
        Assert.areEqual(200, res.getStatusCode());
    }

    @AuraEnabled
    public static void updateObject() {
        String fileNameToUpdate = '/BytesInTheCloud.txt';
        String fileNewContent = 'Data update complete! Your bytes are now even more awesome.';
        HttpResponse res = awsS3Request('PUT', fileNameToUpdate, Blob.valueOf(fileNewContent), '');
    }

    @AuraEnabled
    public static void deleteObject() {
        String fileNameToDelete = '/Dog_3.jpg';
        HttpResponse res = awsS3Request('DELETE', fileNameToDelete, null, '');
        //Checkpoint
        Assert.areEqual(204, res.getStatusCode());
    }

    private static HttpResponse awsS3Request(String method, String endpoint, Blob body, String contentType) {

        HttpRequest request = new HttpRequest();
        request.setMethod(method);
        if (body != null) {
            request.setBodyAsBlob(body);
        }
        request.setEndpoint('callout:AWS_S3' + endpoint);
        if (String.isNotBlank(contentType)) {
            request.setHeader('Content-Type', contentType);
        }
        Http http = new Http();
        HttpResponse resp = http.send(request);
        //Checkpoint
        Assert.areEqual(200, resp.getStatusCode());
        return resp;
    }

    private static String md5fileName(String originalFilename) {
        String salt = 'USTDirImage';
        Blob fileNameBlob = Blob.valueOf(originalFilename + salt);
        Blob hasFileNameBlob = Crypto.generateDigest('MD5', fileNameBlob);
        return EncodingUtil.convertToHex(hasFileNameBlob);
    }

}