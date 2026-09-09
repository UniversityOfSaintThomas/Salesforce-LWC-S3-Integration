/**
 * Mock that simulates a failed AWS S3 callout (non-2xx status), used to test
 * that awsS3Request/deleteOldFile throw AwsS3CalloutException on failure.
 */
@IsTest
global class awsDirImgFailedRequestMock implements HttpCalloutMock {
    global HttpResponse respond(HttpRequest request) {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(500);
        return response;
    }
}
