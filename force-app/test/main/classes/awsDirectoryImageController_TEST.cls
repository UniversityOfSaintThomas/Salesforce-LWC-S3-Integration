/**
 * Created by Thaddaeus Dahlberg, Software Engineer, University of St. Thomas on 12/3/2024.
 */


@IsTest
private class awsDirectoryImageController_TEST {

    @TestSetup
    static void setup() {
        Contact testContact = new Contact(LastName = 'Test', FirstName = 'Contact');
        insert testContact;
        // Add setup logic here
    }

    //public class CalloutStaticClass {

    public static HttpResponse getInfoFromExternalService(String endpoint) {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            Http h = new Http();
            HttpResponse res = h.send(req);
            return res;
        }
    //}

/*    @isTest
    global class MockHttpResponseGenerator implements HttpCalloutMock {
        global HTTPResponse respond(HTTPRequest req){
            try{
                if(req.getEndpoint()=='https://any_endpoint_here.com'){
                    HttpResponse res= new HttpResponse();
                    res.setHeader('Content-Type','application/json');
                    res.setBody('{"Name ":"Test Name"}');
                    res.setStatusCode(200);
                    return res;
                }
            }catch(Exception ex){
                System.debug('ERROR Message>>>'+ex.getMessage()+' Error Line Number>>> '+ex.getLineNumber());
            }
            return null;
        }
    }*/

    @IsTest
    static void testFindObject() {
        // Set the mock callout
        MultiStaticResourceCalloutMock multiMock = new MultiStaticResourceCalloutMock();
        multiMock.setStaticResource('https://example.com/example/test', 'mockResponse');
        multiMock.setStaticResource('https://example.com/example/sfdc', 'mockResponse2');
        multiMock.setStatusCode(200);
        multiMock.setHeader('Content-Type', 'application/json');

        // Set the mock callout mode
        Test.setMock(HttpCalloutMock.class, multiMock);

        //Get test contact
        Contact testContact = [SELECT Id FROM Contact WHERE LastName = 'Test' AND FirstName = 'Contact' LIMIT 1];

        // Setup
        String recordId = testContact.Id;
        Boolean deletePrevious = false;

        // Test
        Test.startTest();
        String result = awsDirectoryImageController.findObject(recordId, deletePrevious, '');
        Test.stopTest();

        // Verify
        System.assertNotEquals(null, result, 'The result should not be null');
    }

/*    @IsTest
    static void testAddObjectsToBucket() {
        // Set the mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());

        Contact testContact = [SELECT Id FROM Contact WHERE LastName = 'Test' AND FirstName = 'Contact' LIMIT 1];
        // Setup
        String fileType = 'image/jpeg';
        Id recordId = testContact.Id;
        String base64FileContent = 'iVBORw0KGgoAAAANSUhEUgAAAAUA';
        String imageField = 'Department';

        // Test
        Test.startTest();
        String result = awsDirectoryImageController.addObjectsToBucket(fileType, recordId, base64FileContent, imageField, '_TEST');
        Test.stopTest();

        // Verify
        System.assertNotEquals('', result, 'The result should not be empty');
    }*/

/*    @IsTest
    static void testUpdateRecord() {
        // Setup
        Id recordId = '001xx000003DGbYAAW';
        String imageField = 'Department';
        String imageLink = 'https://example.com/image.png';

        // Test
        Test.startTest();
        awsDirectoryImageController.updateRecord(recordId, imageField, imageLink);
        Test.stopTest();

        // Verify
        SObject sObj = [SELECT Id, Department FROM Account WHERE Id = :recordId];
        System.assertEquals('<img src="https://example.com/image.png" />', sObj.get(imageField), 'The image link should be updated');
    }*/

    @IsTest
    static void testDeleteOldFile() {
        // Setup
        List<String> keysToDelete = new List<String>{
                'file1.png', 'file2.png'
        };

        // Test
        Test.startTest();
        awsDirectoryImageController.deleteOldFile(keysToDelete);
        Test.stopTest();

        // Verify
        // Add appropriate verification logic if possible
    }

    @IsTest
    static void testMd5fileName() {
        // Setup
        String fileName = 'testfile';
        Blob fileNameBlob = Blob.valueOf(fileName + 'USTDirImage');
        Blob hasFileNameBlob = Crypto.generateDigest('MD5', fileNameBlob);
        String testString = EncodingUtil.convertToHex(hasFileNameBlob);
        // Test
        Test.startTest();
        String result = awsDirectoryImageController.md5fileName(fileName);
        Test.stopTest();

        // Verify
        System.assertEquals(testString, result, 'md5 encryption matches');
    }
}