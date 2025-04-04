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
    public static String findObject(String recordId, Boolean deletePrevious, String fileNameSuffix) {
        String bucketLink = getBucketLink();
        String fileName = md5fileName(recordId);
        if (String.isNotBlank(fileNameSuffix)) {
            fileName += fileNameSuffix;
        }
        String imageLink;
        String endPoint = '?prefix=' + EncodingUtil.urlEncode(fileName, 'UTF-8') + '.';
        HttpResponse res = awsS3Request('GET', endPoint, null, '');
        System.debug('res: ' + res.toString());
        String namespace = 'http://s3.amazonaws.com/doc/2006-03-01/';
        Dom.Document doc = res.getBodyDocument();
        Dom.XmlNode root = doc.getRootElement();
        System.debug('doc: ' + doc);

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
    public static String addObjectsToBucket(String fileType, Id recordId, String base64FileContent, String imageField, String fileNameSuffix) {
        String bucketLink = getBucketLink();
        String fileSuffix = fileType.replace('image/', '');
        if (fileSuffix == 'jpeg') {
            fileSuffix = 'jpg';
        }
        Blob fileBody = EncodingUtil.base64Decode(base64FileContent);
        findObject(recordId, true, fileNameSuffix);
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
        String sObjName;
        try {
            myRecordId = recordId;
            sObjName = myRecordId.getSObjectType().getDescribe().getName();
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
        }
        if (String.isNotBlank(imageField) && String.isNotBlank(sObjName)) {
            SObject sObj = Database.query('SELECT Id, ' + imageField + ' FROM ' + sObjName + ' WHERE Id = :myRecordId');
            Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(sObjName);
            Schema.DescribeSObjectResult describeSObjectResult = sObjectType.getDescribe();
            Schema.DescribeFieldResult fieldResult = describeSObjectResult.fields.getMap().get(imageField).getDescribe();
            String imageLinkField = imageLink;
            if (fieldResult.isHtmlFormatted()) {
                imageLinkField = '<img src="' + imageLinkField + '" />';
            }

            sObj.put(imageField, imageLinkField);
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