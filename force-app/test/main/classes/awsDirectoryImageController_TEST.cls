/**
 * Created by Thaddaeus Dahlberg, Software Engineer, University of St. Thomas on 12/3/2024.
 */

@IsTest(SeeAllData=true)
private class awsDirectoryImageController_TEST {

    @IsTest
    static void testFindObject() {
        Account newAccount = new Account(Name = 'Test Account');
        insert newAccount;
        Test.setMock(HttpCalloutMock.class, new awsDirectoryImageControllerMock());
        Test.startTest();
        String imageLink = awsDirectoryImageController.findObject(newAccount.Id, true, '', 'Description');
        Test.stopTest();
        Assert.areEqual(null, imageLink);
    }

    @IsTest
    static void testFindObjectDeletePreviousClearsField() {
        Account newAccount = new Account(Name = 'Test Account', Description = 'https://example.com/old-image.jpg');
        insert newAccount;
        Test.setMock(HttpCalloutMock.class, new awsDirImgFoundObjectMock());
        Test.startTest();
        String imageLink = awsDirectoryImageController.findObject(newAccount.Id, true, '', 'Description');
        Test.stopTest();
        Assert.areEqual(null, imageLink);
        Account updatedAccount = [SELECT Description FROM Account WHERE Id = :newAccount.Id];
        Assert.areEqual(null, updatedAccount.Description);
    }

    @IsTest
    static void testAddObjectsToBucket() {
        ConnectApi.NamedCredential nc = ConnectApi.NamedCredentials.getNamedCredential('AWS_S3_Directory_Image');
        Account newAccount = new Account(Name = 'Test Account');
        insert newAccount;
        String md5Id = awsDirectoryImageController.md5fileName(newAccount.Id);
        Test.setMock(HttpCalloutMock.class, new awsDirectoryImageControllerMock());
        Test.startTest();
        String imageLink = awsDirectoryImageController.addObjectsToBucket('image/jpeg', newAccount.Id, 'base64FileContent', 'Description', '');
        Test.stopTest();
        //get the t value out of the image link
        List<String> imageLinkParts = imageLink.split('\\?');
        Assert.areEqual(nc.calloutUrl + '/' + md5Id + '.jpg?' + imageLinkParts[1], imageLink);
    }

    @IsTest
    static void testUpdateRecord() {
        Account newAccount = new Account(Name = 'Test Account', Description = 'https://example.com/old-image.jpg');
        insert newAccount;
        Test.startTest();
        awsDirectoryImageController.updateRecord(newAccount.Id, 'Description', null);
        Test.stopTest();
        Account updatedAccount = [SELECT Description FROM Account WHERE Id = :newAccount.Id];
        Assert.areEqual(null, updatedAccount.Description);
    }

    @IsTest
    static void testUpdateRecordInvalidFieldIsNoOp() {
        Account newAccount = new Account(Name = 'Test Account', Description = 'https://example.com/old-image.jpg');
        insert newAccount;
        Test.startTest();
        awsDirectoryImageController.updateRecord(newAccount.Id, 'NotARealField__c', 'https://example.com/new-image.jpg');
        Test.stopTest();
        Account updatedAccount = [SELECT Description FROM Account WHERE Id = :newAccount.Id];
        Assert.areEqual('https://example.com/old-image.jpg', updatedAccount.Description);
    }

    @IsTest
    static void testGetBucketLink() {
        ConnectApi.NamedCredential nc = ConnectApi.NamedCredentials.getNamedCredential('AWS_S3_Directory_Image');
        Test.startTest();
        String bucketLink = awsDirectoryImageController.getBucketLink();
        Test.stopTest();
        Assert.areEqual(nc.calloutUrl + '/', bucketLink);
    }

    @IsTest
    static void testAwsS3Request() {
        Test.setMock(HttpCalloutMock.class, new awsDirectoryImageControllerMock());
        Test.startTest();
        HttpResponse response = awsDirectoryImageController.awsS3Request('GET', 'endpoint', Blob.valueOf('body'), 'contentType');
        Test.stopTest();
        Assert.areEqual(200, response.getStatusCode());
    }

    @IsTest
    static void testAwsS3RequestThrowsOnFailure() {
        Test.setMock(HttpCalloutMock.class, new awsDirImgFailedRequestMock());
        Test.startTest();
        try {
            awsDirectoryImageController.awsS3Request('GET', 'endpoint', Blob.valueOf('body'), 'contentType');
            Assert.fail('Expected AwsS3CalloutException to be thrown');
        } catch (awsDirectoryImageController.AwsS3CalloutException e) {
            Assert.isTrue(e.getMessage().contains('500'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testDeleteOldFileThrowsOnFailure() {
        Test.setMock(HttpCalloutMock.class, new awsDirImgFailedRequestMock());
        Test.startTest();
        try {
            awsDirectoryImageController.deleteOldFile(new List<String>{'some-key.jpg'});
            Assert.fail('Expected AwsS3CalloutException to be thrown');
        } catch (awsDirectoryImageController.AwsS3CalloutException e) {
            Assert.isTrue(e.getMessage().contains('500'));
        }
        Test.stopTest();
    }
}