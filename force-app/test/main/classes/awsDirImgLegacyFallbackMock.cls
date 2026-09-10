/**
 * Mock that simulates the org-scoped (new) hash prefix having no matching S3
 * object, followed by the legacy hash prefix finding one. Used to test the
 * legacy-hash fallback lookup in findObject/listKeysForPrefix. Deletes succeed.
 */
@IsTest
global class awsDirImgLegacyFallbackMock implements HttpCalloutMock {
    private Integer getCallCount = 0;

    global HttpResponse respond(HttpRequest request) {
        HttpResponse response = new HttpResponse();
        if (request.getMethod() == 'DELETE') {
            response.setStatusCode(204);
            return response;
        }

        getCallCount++;
        response.setHeader('Content-Type', 'application/xml');
        if (getCallCount == 1) {
            // First GET: new org-scoped hash prefix -- no match.
            response.setBody(
                '<?xml version="1.0" encoding="UTF-8"?>' +
                '<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">' +
                '</ListBucketResult>'
            );
        } else {
            // Second GET: legacy hash prefix -- match found.
            response.setBody(
                '<?xml version="1.0" encoding="UTF-8"?>' +
                '<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">' +
                '<Contents>' +
                '<Key>legacy-test-key.jpg</Key>' +
                '<LastModified>2024-01-01T00:00:00.000Z</LastModified>' +
                '</Contents>' +
                '</ListBucketResult>'
            );
        }
        response.setStatusCode(200);
        return response;
    }
}
