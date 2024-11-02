/**
 * Created by Thaddaeus Dahlberg, Software Engineer, University of St. Thomas on 10/22/2024.
 */


public with sharing class awsS3Controller {

    private final static String bucketLink = 'https://stthomas-dev-salesforce-directory-images.s3.us-east-1.amazonaws.com/';

    @AuraEnabled
    public static String findObject(String recordId, Boolean deletePrevious) {
        String fileName = md5fileName(recordId);
        String imageLink = bucketLink;
        String endPoint = '?prefix=' + EncodingUtil.urlEncode(fileName, 'UTF-8') + '.';
        HttpResponse res = awsS3Request('GET', endPoint, null, '');

        String namespace = 'http://s3.amazonaws.com/doc/2006-03-01/';
        Dom.Document doc = res.getBodyDocument();
        Dom.XmlNode root = doc.getRootElement();

        List<String> keysToDelete = new List<String>();
        Datetime lastLastModified = null;

        for (Dom.XmlNode node : root.getChildElements()) {
            if (node.getName() == 'Contents' && node.getNamespace() == namespace) {
                String key = node.getChildElement('Key', namespace).getText();
                Datetime lastModified = Datetime.valueOf(node.getChildElement('LastModified', namespace).getText().replace('T', ' ').replace('Z', ''));
                keysToDelete.add(key);

                if (lastLastModified == null || lastModified < lastLastModified) {
                    imageLink = bucketLink + key;
                    lastLastModified = lastModified;
                }
            }
        }

        if (deletePrevious) {
            deleteOldFile(keysToDelete);
        }

        return String.isNotBlank(imageLink) && !deletePrevious ? imageLink : null;
    }

    @AuraEnabled
    public static String addObjectsToBucket(String fileName, String fileType, Id recordId, String base64FileContent, String recordField) {
        String fileSuffix = fileName.substringAfterLast('.');
        Blob fileBody = EncodingUtil.base64Decode(base64FileContent);

        Id myRecordId;
        String sObjName;
        try {
            myRecordId = recordId;
            sObjName = myRecordId.getSObjectType().getDescribe().getName();
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
        }

        findObject(recordId, true);
        fileName = '/' + md5fileName(recordId) + '.' + fileSuffix;
        HttpResponse res = awsS3Request('PUT', fileName, fileBody, fileType);
        String imageLink = bucketLink + fileName.removeStart('/');

        if (res.getStatusCode() == 200) {
            //Record the image link to the record
            System.debug('imageLinkField: ' + recordField + ' sObjName: ' + sObjName);
            if (String.isNotBlank(recordField) && String.isNotBlank(sObjName)) {
                SObject sObj = Database.query('SELECT Id, ' + recordField + ' FROM ' + sObjName + ' WHERE Id = :myRecordId');
                sObj.put(recordField, imageLink);
                update sObj;
            }
            return imageLink + '?t=' + Datetime.now().getTime();
        }
        return '';
    }

    private static void deleteOldFile(List<String> keysToDelete) {
        Http http = new Http();
        for (String fileName : keysToDelete) {
            HttpRequest request = new HttpRequest();
            request.setMethod('DELETE');
            request.setEndpoint('callout:AWS_S3/' + fileName);
            HttpResponse res = http.send(request);
            Assert.areEqual(204, res.getStatusCode());
        }
    }

    private static HttpResponse awsS3Request(String method, String endpoint, Blob body, String contentType) {
        HttpRequest request = new HttpRequest();
        request.setMethod(method);
        if (body != null) request.setBodyAsBlob(body);
        request.setEndpoint('callout:AWS_S3' + endpoint);
        if (String.isNotBlank(contentType)) request.setHeader('Content-Type', contentType);

        HttpResponse resp = new Http().send(request);
        Assert.areEqual(200, resp.getStatusCode());
        return resp;
    }

    private static String md5fileName(String originalFilename) {
        Blob fileNameBlob = Blob.valueOf(originalFilename + 'USTDirImage');
        Blob hasFileNameBlob = Crypto.generateDigest('MD5', fileNameBlob);
        return EncodingUtil.convertToHex(hasFileNameBlob);
    }
}