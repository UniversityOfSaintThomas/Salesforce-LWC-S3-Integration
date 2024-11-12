/**
 * Created by Thaddaeus Dahlberg, Software Engineer, University of St. Thomas on 10/23/2024.
 */

import {LightningElement, api, track} from 'lwc';
import addObjectsToBucket from '@salesforce/apex/awsS3Controller.addObjectsToBucket';
import findObjectsInBucket from '@salesforce/apex/awsS3Controller.findObject';

export default class AmazonS3DirectoryImage extends LightningElement {

    @api recordId;
    @api imageMaxWidth;
    @api imageMaxHeight;
    @api recordField;
    @api imageMode;

    @track showSpinner = false;
    @track currentImageULR;
    @track imageFound = false;
    @track error;

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
                    this.imageFound = true;
                } else {
                    this.imageFound = false;
                }
                this.showSpinner = false;
            })
            .catch(error => {
                this.error = error;
                console.log('error callback: ' + error);
                this.showSpinner = false;
            })
        console.log('recordId: ' + this.recordId);
        console.log('imageFound: ' + this.imageFound);
    };

    handleDeleteImage() {
        this.showSpinner = true;
        findObjectsInBucket({recordId: this.recordId, deletePrevious: true})
            .then(result => {
                this.currentImageULR = null;
                this.imageFound = false;
                this.showSpinner = false;
            })
            .catch(error => {
                this.error = error;
                console.log('error callback: ' + error);
                this.showSpinner = false;
            })
    }


    //Handle the file upload
    handleUploadFile(event) {
        if (event.detail.files && event.detail.files.length) {
            const uploadedFiles = event.detail.files;
            const imgFile = uploadedFiles[0];
            const fileType = imgFile.type;

            // Validate file type
            const acceptedFormats = this.acceptedFormats;
            const isValidFormat = acceptedFormats.some(format => fileType.endsWith(format.replace('.', '')));

            if (!isValidFormat) {
                this.error = {};
                this.error = 'Invalid file type. Accepted formats are: ' + acceptedFormats.join(', ');
                console.log(this.error);
                this.showSpinner = false;
                return;
            }

            this.showSpinner = true;
            this.currentImageULR = null;

            const apexParams = {
                fileName: imgFile.name,
                fileType: imgFile.type,
                recordId: this.recordId,
                recordField: this.recordField,
            };

            const fileReader = new FileReader();

            fileReader.onloadend = () => {
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
                            this.imageFound = true;
                            this.showSpinner = false;
                        })
                        .catch(error => {
                            console.log('error: ' + error);
                            this.error = error;
                            this.showSpinner = false;
                        });
                };
                img.onerror = (error) => {
                    console.log('error loading image: ' + error);
                    this.error = error;
                    this.showSpinner = false;
                };
            };

            fileReader.onerror = (error) => {
                console.log('error handle upload: ' + error);
                this.error = error;
                this.showSpinner = false;
            };
            this.error = '';
            fileReader.readAsDataURL(imgFile);

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
        let ratio;
        if (mode === 'fit') {
            ratio = Math.max(targetWidth / imgWidth, targetHeight / imgHeight);
        } else {
            ratio = Math.min(targetWidth / imgWidth, targetHeight / imgHeight);
        }
        newWidth = imgWidth * ratio;
        newHeight = imgHeight * ratio;
        canvasCopy.width = newWidth;
        canvasCopy.height = newHeight;
        copyContext.drawImage(img, 0, 0, newWidth, newHeight);
        if (mode === 'resize') {
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