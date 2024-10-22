/**
 * Created by Thaddaeus Dahlberg, Software Engineer, University of St. Thomas on 10/22/2024.
 */


public with sharing class AWS_S3Controller {

    @AuraEnabled
    public static void listBucketObjects() {
        HttpRequest request = new HttpRequest();
        request.setMethod('GET');
        request.setEndpoint('callout:AWS_S3' + '/');
        Http http = new Http();
        HttpResponse res = http.send(request);

        //Checkpoint
        Assert.areEqual(200, res.getStatusCode());

        //The following section processes the XML result and formats the data for better readability.
        String namespace = 'http://s3.amazonaws.com/doc/2006-03-01/';
        Dom.Document doc = res.getBodyDocument();
        Dom.XMLNode root = doc.getRootElement();

        String bucketName = root.getChildElement('Name', namespace).getText();

        System.debug('Bucket Name: ' + bucketName);
        System.debug('The following objects are stored in the bucket: ');

        for (Dom.XMLNode node : root.getChildElements()) {
            if (node.getName() == 'Contents' && node.getNamespace() == namespace) {
                String key = node.getChildElement('Key', namespace).getText();
                String lastModified = node.getChildElement('LastModified', namespace).getText();
                String storageClass = node.getChildElement('StorageClass', namespace).getText();

                System.debug('Key: ' + key);
                System.debug('StorageClass: ' + storageClass);
                System.debug('LastModified: ' + lastModified);
            }
        }
    }

    @AuraEnabled
    public static void addObjectsToBucket() {
        String fileNameToCreate = 'BytesInTheCloud.txt';
        String fileContent = 'Greetings from the cloud! Your data is safe and sound in S3.';

        HttpRequest request = new HttpRequest();
        request.setMethod('PUT');
        request.setBody(fileContent);
        request.setEndpoint('callout:AWS_S3/' + fileNameToCreate);

        Http http = new Http();
        HttpResponse res = http.send(request);

        //Checkpoint
        Assert.areEqual(200, res.getStatusCode());
    }

    @AuraEnabled
    public static void updateObject() {
        String fileNameToUpdate = 'BytesInTheCloud.txt';
        String fileNewContent = 'Data update complete! Your bytes are now even more awesome.';

        HttpRequest request = new HttpRequest();
        request.setMethod('PUT');
        request.setBody(fileNewContent);
        request.setEndpoint('callout:AWS_S3/' + fileNameToUpdate);

        Http http = new Http();
        HttpResponse res = http.send(request);

        //Checkpoint
        Assert.areEqual(200,res.getStatusCode());
    }

    @AuraEnabled
    public static void deleteObject() {
        String fileNameToDelete = 'Dog_3.jpg';

        HttpRequest request = new HttpRequest();
        request.setMethod('DELETE');
        request.setEndpoint('callout:AWS_S3/' + fileNameToDelete);

        Http http = new Http();
        HttpResponse res = http.send(request);

        //Checkpoint
        Assert.areEqual(204,res.getStatusCode());
    }

}