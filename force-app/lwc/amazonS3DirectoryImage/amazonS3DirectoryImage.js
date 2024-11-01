/**
 * Created by Thaddaeus Dahlberg, Software Engineer, University of St. Thomas on 10/23/2024.
 */

import {LightningElement, api, track} from 'lwc';
import addObjectsToBucket from '@salesforce/apex/awsS3Controller.addObjectsToBucket';
import findObjectsInBucket from '@salesforce/apex/awsS3Controller.findObject';

export default class AmazonS3DirectoryImage extends LightningElement {

    @api recordId;
    @api objectAPIName;
    @api imageLinkField;
    @api imageMaxWidth;
    @api imageMaxHeight;
    @api recordField;
    @api imageMode;

    @track showSpinner = false;
    @track currentImageULR;

    get acceptedFormats() {
        return ['.jpg', '.jpeg', '.gif', '.png'];
    }

    //Get the current Image by querying the s3 bucket for recordId;
    connectedCallback() {
        this.showSpinner = true;
        findObjectsInBucket({recordId: this.recordId, deletePrevious: false})
            .then(result => {
                if (result) {
                    this.currentImageULR = result;
                    this.showSpinner = false;
                }
            })
            .catch(error => {
                console.log('error: ' + error);
                this.showSpinner = false;
            })
    };


    //Handle the file upload
    handleUploadFile(event) {
        if (event.detail.files && event.detail.files.length) {
            this.showSpinner = true;
            this.currentImageULR = null;
            const uploadedFiles = event.detail.files;
            if (uploadedFiles.length > 0) {
                const imgFile = event.detail.files[0];

                const apexParams = {
                    fileName: imgFile.name,
                    fileType: imgFile.type,
                    recordId: this.recordId
                };

                const fileReader = new FileReader();
                fileReader.readAsDataURL(imgFile);
                fileReader.onloadend = (() => {
                    let result = fileReader.result;
                    // build the base64 string and add it to the apexParams
                    const base64 = 'base64,';
                    const i = result.indexOf(base64) + base64.length;
                    apexParams.base64FileContent = result.substring(i);

                    // Create an image element to resize
                    const img = new Image();
                    img.src = result;
                    img.onload = () => {
                        // Resize the image
                        const resizedImgDataUrl = this.resizeImg(img, this.imageMaxWidth, this.imageMaxHeight, 0); // Example dimensions and no rotation
                        const resizedBase64 = resizedImgDataUrl.split(base64)[1];
                        apexParams.base64FileContent = resizedBase64;

                        // Call the apex method to add the image to the S3 bucket
                        addObjectsToBucket(apexParams)
                            .then(result => {
                                this.currentImageULR = result;

                                this.showSpinner = false;
                            })
                            .catch(error => {
                                console.log('error: ' + error);
                                this.showSpinner = false;
                            });
                    };
                });
            }
        }
    }

    resizeImg(img, targetWidth, targetHeight, degrees) {
        const imgWidth = img.width;
        const imgHeight = img.height;
        const mode = this.imageMode.toLowerCase();

        let newWidth, newHeight;
        const canvasCopy = document.createElement("canvas");
        const copyContext = canvasCopy.getContext("2d");
        const canvas = document.createElement("canvas");
        const canvasContext = canvas.getContext("2d");

        if (mode === 'fit') {
            const ratio = Math.max(targetWidth / imgWidth, targetHeight / imgHeight);
            newWidth = imgWidth * ratio;
            newHeight = imgHeight * ratio;
        } else if (mode === 'resize') {
            const ratio = Math.min(targetWidth / imgWidth, targetHeight / imgHeight);
            newWidth = imgWidth * ratio;
            newHeight = imgHeight * ratio;

            return canvasCopy.toDataURL();
        }

        canvasCopy.width = newWidth;
        canvasCopy.height = newHeight;
        copyContext.drawImage(img, 0, 0, newWidth, newHeight);
        if(mode === 'resize'){
            return canvasCopy.toDataURL();
        }
        canvas.width = targetWidth;
        canvas.height = targetHeight;

        const offsetX = (newWidth - targetWidth) / 2;
        const offsetY = (newHeight - targetHeight) / 2;

        canvasContext.clearRect(0, 0, canvas.width, canvas.height);
        canvasContext.translate(canvas.width / 2, canvas.height / 2);
        canvasContext.rotate(degrees * Math.PI / 180);
        canvasContext.drawImage(canvasCopy, -targetWidth / 2 - offsetX, -targetHeight / 2 - offsetY, newWidth, newHeight);

        return canvas.toDataURL();
    }
}