/**
 * Mock that simulates an existing S3 object being found (GET) and successfully
 * deleted (DELETE), used to test the delete-clears-field behavior.
 */
@IsTest
global class awsDirImgFoundObjectMock implements HttpCalloutMock {
    global HttpResponse respond(HttpRequest request) {
        HttpResponse response = new HttpResponse();
        if (request.getMethod() == 'DELETE') {
            response.setStatusCode(204);
            return response;
        }
        response.setHeader('Content-Type', 'application/xml');
        response.setBody(
            '<?xml version="1.0" encoding="UTF-8"?>' +
            '<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">' +
            '<Contents>' +
            '<Key>test-key.jpg</Key>' +
            '<LastModified>2025-01-01T00:00:00.000Z</LastModified>' +
            '</Contents>' +
            '</ListBucketResult>'
        );
        response.setStatusCode(200);
        return response;
    }
}
