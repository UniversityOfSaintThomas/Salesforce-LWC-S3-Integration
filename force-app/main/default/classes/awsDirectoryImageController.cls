/**
 * Created by Thaddaeus Dahlberg, Software Engineer, University of St. Thomas on 10/22/2024.
 */


public with sharing class awsDirectoryImageController {

    private final static String bucketLink = 'https://stthomas-dev-salesforce-directory-images.s3.us-east-1.amazonaws.com/';

    @AuraEnabled
    public static String findObject(String recordId, Boolean deletePrevious) {
        String fileName = md5fileName(recordId);
        String imageLink;
        String endPoint = '?prefix=' + EncodingUtil.urlEncode(fileName, 'UTF-8') + '.';
        HttpResponse res = awsS3Request('GET', endPoint, null, '');
        System.debug('res-body: ' + res.getBodyDocument());
        String namespace = 'http://s3.amazonaws.com/doc/2006-03-01/';
        Dom.Document doc = res.getBodyDocument();
        System.debug('doc: ' + doc);
        Dom.XmlNode root = doc.getRootElement();
        System.debug('root: ' + root);

        List<String> keysToDelete = new List<String>();
        Datetime lastLastModified = null;

        for (Dom.XmlNode node : root.getChildElements()) {
            if (node.getName() == 'Contents' && node.getNamespace() == namespace) {
                String key = node.getChildElement('Key', namespace).getText();
                Datetime lastModified = Datetime.valueOf(node.getChildElement('LastModified', namespace).getText().replace('T', ' ').replace('Z', ''));
                keysToDelete.add(key);
                imageLink = bucketLink + key;
                lastLastModified = lastModified;
            }
        }

        if (deletePrevious) {
            deleteOldFile(keysToDelete);
        }

        return String.isNotBlank(imageLink) && !deletePrevious ? imageLink : null;
    }

    @AuraEnabled
    public static String addObjectsToBucket(String fileType, Id recordId, String base64FileContent, String recordField) {

        String fileSuffix = fileType.replace('image/', '');
        if (fileSuffix == 'jpeg') {
            fileSuffix = 'jpg';
        }
        Blob fileBody = EncodingUtil.base64Decode(base64FileContent);
        findObject(recordId, true);
        String fileName = '/' + md5fileName(recordId) + '.' + fileSuffix;
        HttpResponse res = awsS3Request('PUT', fileName, fileBody, fileType);
        String imageLink = bucketLink + fileName.removeStart('/');

        if (res.getStatusCode() == 200) {
            updateRecord(recordId, recordField, imageLink);
            return imageLink + '?t=' + Datetime.now().getTime();
        }
        return '';
    }

    @TestVisible
    private static void updateRecord(Id recordId, String recordField, String imageLink) {
        Id myRecordId;
        String sObjName;
        try {
            myRecordId = recordId;
            sObjName = myRecordId.getSObjectType().getDescribe().getName();
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
        }
        if (String.isNotBlank(recordField) && String.isNotBlank(sObjName)) {
            SObject sObj = Database.query('SELECT Id, ' + recordField + ' FROM ' + sObjName + ' WHERE Id = :myRecordId');
            Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(sObjName);
            Schema.DescribeSObjectResult describeSObjectResult = sObjectType.getDescribe();
            Schema.DescribeFieldResult fieldResult = describeSObjectResult.fields.getMap().get(recordField).getDescribe();
            String imageLinkField = imageLink;
            if (fieldResult.isHtmlFormatted()) {
                imageLinkField = '<img src="' + imageLinkField + '" />';
            }

            sObj.put(recordField, imageLinkField);
            update sObj;
        }
    }

    @TestVisible
    private static void deleteOldFile(List<String> keysToDelete) {
        Http http = new Http();
        for (String fileName : keysToDelete) {
            HttpRequest request = new HttpRequest();
            request.setMethod('DELETE');
            request.setEndpoint('callout:AWS_S3_Directory_Image/' + fileName);
            HttpResponse res = http.send(request);
            Assert.areEqual(204, res.getStatusCode());
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
        Assert.areEqual(200, resp.getStatusCode());
        return resp;
    }

    @TestVisible
    private static String md5fileName(String originalFilename) {
        Blob fileNameBlob = Blob.valueOf(originalFilename + 'USTDirImage');
        Blob hasFileNameBlob = Crypto.generateDigest('MD5', fileNameBlob);
        return EncodingUtil.convertToHex(hasFileNameBlob);
    }
}