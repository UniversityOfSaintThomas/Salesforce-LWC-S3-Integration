/**
 * Created by Thaddaeus Dahlberg, Software Engineer, University of St. Thomas on 10/23/2024.
 */

import {LightningElement, api} from 'lwc';
import addObjectsToBucket from '@salesforce/apex/awsS3Controller.addObjectsToBucket';

export default class AmazonS3DirectoryImage extends LightningElement {

    @api recordId;

    isUploading = false;

    get acceptedFormats() {
        return ['.jpg', '.jpeg', '.gif', '.png'];
    }

    handleUploadFile(event) {
        console.log('handleUploadFinished');
        if (event.detail.files && event.detail.files.length) {
            const uploadedFiles = event.detail.files;
            if (uploadedFiles.length > 0) {

                const imgFile = event.detail.files[0];
                console.log('imgFile: ' + JSON.stringify(imgFile, null, 2));
                const apexParams = {
                    fileName: imgFile.name,
                    fileType: imgFile.type,
                    recordId: this.recordId
                };

                const fileReader = new FileReader();
                fileReader.onloadend = (() => {

                    let result = fileReader.result;

                    //build the base64 string and add it to the apexParams
                    const base64 = 'base64,';
                    const i = result.indexOf(base64) + base64.length;
                    apexParams.base64FileContent = result.substring(i);

                    //Call the apex method to add the image to the S3 bucket
                    addObjectsToBucket(apexParams)
                        .then(result => {
                            console.log('result: ' + result);
                        })
                        .catch(error => {
                            console.log('error: ' + error);
                        });

                });
                fileReader.readAsDataURL(imgFile);
            }
        }
    }


}