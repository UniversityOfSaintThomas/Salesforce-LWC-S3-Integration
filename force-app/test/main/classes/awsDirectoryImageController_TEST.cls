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
    static void testFindObjectFallsBackToLegacyHashAndClearsField() {
        Account newAccount = new Account(Name = 'Test Account', Description = 'https://example.com/old-image.jpg');
        insert newAccount;
        Test.setMock(HttpCalloutMock.class, new awsDirImgLegacyFallbackMock());
        Test.startTest();
        String imageLink = awsDirectoryImageController.findObject(newAccount.Id, true, '', 'Description');
        Test.stopTest();
        Assert.areEqual(null, imageLink);
        Account updatedAccount = [SELECT Description FROM Account WHERE Id = :newAccount.Id];
        Assert.areEqual(null, updatedAccount.Description);
    }

    @IsTest
    static void testFindObjectFallsBackToLegacyHashOnLookup() {
        Account newAccount = new Account(Name = 'Test Account');
        insert newAccount;
        ConnectApi.NamedCredential nc = ConnectApi.NamedCredentials.getNamedCredential('AWS_S3_Directory_Image');
        Test.setMock(HttpCalloutMock.class, new awsDirImgLegacyFallbackMock());
        Test.startTest();
        String imageLink = awsDirectoryImageController.findObject(newAccount.Id, false, '', 'Description');
        Test.stopTest();
        Assert.areEqual(nc.calloutUrl + '/legacy-test-key.jpg', imageLink);
    }

    @IsTest
    static void testFindObjectNoMatchInEitherHashReturnsNull() {
        Account newAccount = new Account(Name = 'Test Account');
        insert newAccount;
        Test.setMock(HttpCalloutMock.class, new awsDirectoryImageControllerMock());
        Test.startTest();
        String imageLink = awsDirectoryImageController.findObject(newAccount.Id, false, '', 'Description');
        Test.stopTest();
        Assert.areEqual(null, imageLink);
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
    static void testUpdateRecordInvalidFieldThrows() {
        Account newAccount = new Account(Name = 'Test Account', Description = 'https://example.com/old-image.jpg');
        insert newAccount;
        Test.startTest();
        try {
            awsDirectoryImageController.updateRecord(newAccount.Id, 'NotARealField__c', 'https://example.com/new-image.jpg');
            Assert.fail('Expected AwsS3CalloutException to be thrown for an invalid field');
        } catch (awsDirectoryImageController.AwsS3CalloutException e) {
            Assert.isTrue(e.getMessage().contains('does not exist'));
        }
        Test.stopTest();
        Account updatedAccount = [SELECT Description FROM Account WHERE Id = :newAccount.Id];
        Assert.areEqual('https://example.com/old-image.jpg', updatedAccount.Description, 'Field should be unchanged when the update throws');
    }

    @IsTest
    static void testUpdateRecordInvalidIdThrows() {
        Test.startTest();
        try {
            awsDirectoryImageController.updateRecord(null, 'Description', 'https://example.com/new-image.jpg');
            Assert.fail('Expected AwsS3CalloutException to be thrown for a blank record Id');
        } catch (awsDirectoryImageController.AwsS3CalloutException e) {
            Assert.isTrue(e.getMessage().contains('not valid'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testFindObjectThrowsWhenRecordIdMissing() {
        Test.startTest();
        try {
            awsDirectoryImageController.findObject(null, false, '', 'Description');
            Assert.fail('Expected AwsS3CalloutException to be thrown for a missing record Id');
        } catch (awsDirectoryImageController.AwsS3CalloutException e) {
            Assert.isTrue(e.getMessage().contains('record Id'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testFindObjectThrowsWhenImageFieldMissing() {
        Account newAccount = new Account(Name = 'Test Account');
        insert newAccount;
        Test.startTest();
        try {
            awsDirectoryImageController.findObject(newAccount.Id, false, '', '');
            Assert.fail('Expected AwsS3CalloutException to be thrown for a missing image field');
        } catch (awsDirectoryImageController.AwsS3CalloutException e) {
            Assert.isTrue(e.getMessage().contains('image field'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testAddObjectsToBucketThrowsWhenRecordIdMissing() {
        Test.startTest();
        try {
            awsDirectoryImageController.addObjectsToBucket('image/jpeg', null, 'base64FileContent', 'Description', '');
            Assert.fail('Expected AwsS3CalloutException to be thrown for a missing record Id');
        } catch (awsDirectoryImageController.AwsS3CalloutException e) {
            Assert.isTrue(e.getMessage().contains('record Id'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testAddObjectsToBucketThrowsOnUnsupportedFileType() {
        Account newAccount = new Account(Name = 'Test Account');
        insert newAccount;
        Test.startTest();
        try {
            awsDirectoryImageController.addObjectsToBucket('application/pdf', newAccount.Id, 'base64FileContent', 'Description', '');
            Assert.fail('Expected AwsS3CalloutException to be thrown for an unsupported file type');
        } catch (awsDirectoryImageController.AwsS3CalloutException e) {
            Assert.isTrue(e.getMessage().contains('Unsupported file type'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testAddObjectsToBucketThrowsWhenFileContentMissing() {
        Account newAccount = new Account(Name = 'Test Account');
        insert newAccount;
        Test.startTest();
        try {
            awsDirectoryImageController.addObjectsToBucket('image/jpeg', newAccount.Id, '', 'Description', '');
            Assert.fail('Expected AwsS3CalloutException to be thrown for missing file content');
        } catch (awsDirectoryImageController.AwsS3CalloutException e) {
            Assert.isTrue(e.getMessage().contains('No file content'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testAddObjectsToBucketDeletesPreviousBeforeFinalDml() {
        // Regression test: addObjectsToBucket must not perform DML between callouts.
        // With deletePrevious wired through findAndDeletePreviousKeys (callout-only),
        // the single DML write happens after the PUT callout, avoiding
        // "You have uncommitted work pending. Please commit or rollback before calling out."
        Account newAccount = new Account(Name = 'Test Account', Description = 'https://example.com/old-image.jpg');
        insert newAccount;
        Test.setMock(HttpCalloutMock.class, new awsDirImgFoundObjectMock());
        Test.startTest();
        String imageLink = awsDirectoryImageController.addObjectsToBucket('image/jpeg', newAccount.Id, 'base64FileContent', 'Description', '');
        Test.stopTest();
        Assert.isTrue(String.isNotBlank(imageLink), 'A new image link should be returned');
        Account updatedAccount = [SELECT Description FROM Account WHERE Id = :newAccount.Id];
        Assert.isTrue(updatedAccount.Description.startsWith('https://'), 'Field should be updated to the new image link, not left as the old value');
    }

    @IsTest
    static void testMd5FileNameDiffersFromLegacy() {
        Account newAccount = new Account(Name = 'Test Account');
        insert newAccount;
        Test.startTest();
        String newHash = awsDirectoryImageController.md5fileName(newAccount.Id);
        String legacyHash = awsDirectoryImageController.md5fileNameLegacy(newAccount.Id);
        Test.stopTest();
        Assert.areNotEqual(legacyHash, newHash, 'Org-scoped hash should differ from the legacy hash');
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