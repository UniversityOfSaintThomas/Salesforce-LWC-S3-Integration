/**
 * Created by Thaddaeus Dahlberg, Software Engineer, University of St. Thomas on 12/3/2024.
 */


@IsTest
private class awsDirectoryImageController_TEST {

    private class MockHttpResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            // Create a fake response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"success"}');
            res.setStatusCode(200);
            return res;
        }
    }

    @IsTest
    static void testAwsS3Request() {
        // Set the mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());

        // Test data
        String method = 'GET';
        String endpoint = '/test-endpoint';
        Blob body = null;
        String contentType = 'application/json';

        // Test
        Test.startTest();
        HttpResponse response = awsDirectoryImageController.awsS3Request(method, endpoint, body, contentType);
        Test.stopTest();

        // Verify
        System.assertEquals(200, response.getStatusCode(), 'The response status code should be 200');
        System.assertEquals('{"status":"success"}', response.getBody(), 'The response body should match the mock response');
    }

    @IsTest
    static void testFindObject() {

        // Set the mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());

        // Setup
        String recordId = '001xx000003DGbYAAW';
        Boolean deletePrevious = false;

        // Test
        Test.startTest();
        String result = awsDirectoryImageController.findObject(recordId, deletePrevious, '');
        Test.stopTest();

        // Verify
        System.assertNotEquals(null, result, 'The result should not be null');
    }

    @IsTest
    static void testAddObjectsToBucket() {
        // Setup
        // Set the mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());

        String fileType = 'image/png';
        Id recordId = '001xx000003DGbYAAW';
        String base64FileContent = 'iVBORw0KGgoAAAANSUhEUgAAAAUA';
        String recordField = 'Image_Field__c';

        // Test
        Test.startTest();
        String result = awsDirectoryImageController.addObjectsToBucket(fileType, recordId, base64FileContent, recordField, '');
        Test.stopTest();

        // Verify
        System.assertNotEquals('', result, 'The result should not be empty');
    }

/*    @IsTest
    static void testUpdateRecord() {
        // Setup
        Id recordId = '001xx000003DGbYAAW';
        String recordField = 'Image_Field__c';
        String imageLink = 'https://example.com/image.png';

        // Test
        Test.startTest();
        awsDirectoryImageController.updateRecord(recordId, recordField, imageLink);
        Test.stopTest();

        // Verify
        SObject sObj = [SELECT Id, Image_Field__c FROM Account WHERE Id = :recordId];
        System.assertEquals('<img src="https://example.com/image.png" />', sObj.get(recordField), 'The image link should be updated');
    }

    @IsTest
    static void testDeleteOldFile() {
        // Setup
        List<String> keysToDelete = new List<String>{'file1.png', 'file2.png'};

        // Test
        Test.startTest();
        awsDirectoryImageController.deleteOldFile(keysToDelete);
        Test.stopTest();

        // Verify
        // Add appropriate verification logic if possible
    }

    @IsTest
    static void testAwsS3Request() {
        // Setup
        String method = 'GET';
        String endpoint = '/test-endpoint';
        Blob body = null;
        String contentType = 'application/json';

        // Test
        Test.startTest();
        HttpResponse response = awsDirectoryImageController.awsS3Request(method, endpoint, body, contentType);
        Test.stopTest();

        // Verify
        System.assertEquals(200, response.getStatusCode(), 'The response status code should be 200');
    }

    @IsTest
    static void testMd5fileName() {
        // Setup
        String originalFilename = 'testfile';

        // Test
        Test.startTest();
        String result = awsDirectoryImageController.md5fileName(originalFilename);
        Test.stopTest();

        // Verify
        System.assertNotEquals(null, result, 'The result should not be null');
    }*/
}