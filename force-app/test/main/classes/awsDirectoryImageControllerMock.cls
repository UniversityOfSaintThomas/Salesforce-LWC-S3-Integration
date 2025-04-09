/**
 * Created by Thad-PC-2019 on 4/7/2025.
 */

@IsTest
global class awsDirectoryImageControllerMock implements HttpCalloutMock {
    global HttpResponse respond(HttpRequest request) {
        // Create a mock response
        HttpResponse response = new HttpResponse();
        response.setHeader('Content-Type', 'application/xml');
        response.setBody('<?xml version="1.0" encoding="UTF-8"?><root></root>');
        response.setStatusCode(200);
        return response;
    }
}