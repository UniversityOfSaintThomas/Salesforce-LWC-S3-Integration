/**
 * Created by Thaddaeus Dahlberg, Software Engineer, University of St. Thomas on 12/3/2024.
 */

@IsTest(SeeAllData=true)
private class awsDirectoryImageController_TEST {

    @IsTest
    static void testFindObject() {
        Test.setMock(HttpCalloutMock.class, new awsDirectoryImageControllerMock());
        Test.startTest();
        String imageLink = awsDirectoryImageController.findObject(String.valueOf([SELECT Id FROM Account LIMIT 1].Id), true, '', 'Description');
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
        Account newAccount = new Account(Name = 'Test Account');
        insert newAccount;
        Test.startTest();
        awsDirectoryImageController.updateRecord(newAccount.Id, 'Description', 'https://td-aws-dev-s3b.s3.us-west-2.amazonaws.com/fileName');
        Test.stopTest();
        Assert.areEqual(null, newAccount.Description);
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
}