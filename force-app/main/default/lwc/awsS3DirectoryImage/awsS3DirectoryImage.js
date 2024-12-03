/**
 * Created by Thaddaeus Dahlberg, Software Engineer, University of St. Thomas on 10/23/2024.
 */

import {api, LightningElement, track} from 'lwc';
import addObjectsToBucket from '@salesforce/apex/awsDirectoryImageController.addObjectsToBucket';
import findObjectsInBucket from '@salesforce/apex/awsDirectoryImageController.findObject';
import {RefreshEvent} from 'lightning/refresh';

export default class AwsS3DirectoryImage extends LightningElement {

    @api recordId;
    @api imageMaxWidth;
    @api imageMaxHeight;
    @api recordField;
    @api imageMode;
    @api fileNameSuffix;
    @api incomingRecordId;

    @track showSpinner = false;
    @track currentImageULR;
    @track imageFound = false;
    @track error;
    imageFiles = [];

    get acceptedFormats() {
        return ['.jpg', '.jpeg', '.gif', '.png'];
    }

    //Get the current Image by querying the s3 bucket for recordId;
    connectedCallback() {
        this.showSpinner = true;
        if (this.incomingRecordId) {
            this.recordId = this.incomingRecordId;
        }
        findObjectsInBucket({recordId: this.recordId, deletePrevious: false, fileNameSuffix: this.fileNameSuffix})
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
                this.showSpinner = false;
            })
    };

    handleDeleteImage() {
        this.showSpinner = true;
        findObjectsInBucket({recordId: this.recordId, deletePrevious: true, fileNameSuffix: this.fileNameSuffix})
            .then(result => {
                this.currentImageULR = null;
                this.imageFound = false;
                this.showSpinner = false;
            })
            .catch(error => {
                this.error = error;
                this.showSpinner = false;
            })
    }

    readFile(fileSource) {
        return new Promise((resolve, reject) => {
            const fileReader = new FileReader();
            fileReader.onerror = () => reject(fileReader.error);
            fileReader.onload = () => {
                resolve(fileReader.result);
            }
            fileReader.readAsDataURL(fileSource);
        });
    }

    //Handle the file upload
    async handleUploadFile(event) {
        this.error = undefined;
        this.showSpinner = true;
        try {
            this.imageFiles = await Promise.all(
                [...event.target.files].map(file => this.readFile(file))
            );

            if (this.imageFiles.length > 0) {
                let imageFile = await this.resizeImg(this.imageFiles[0]);
                const [dataTypeFull, base64Value] = imageFile.split(',');
                const dataType = dataTypeFull.split(':')[1].split(';')[0];
                addObjectsToBucket({
                    fileType: dataType,
                    recordId: this.recordId,
                    base64FileContent: base64Value,
                    recordField: this.recordField,
                    fileNameSuffix: this.fileNameSuffix
                })
                    .then(result => {
                        this.currentImageULR = result;
                        this.imageFound = true;
                        this.showSpinner = false;
                        this.dispatchEvent(new RefreshEvent());
                    })
                    .catch(error => {
                        this.error = error;
                        this.showSpinner = false;
                    });
            } else {
                this.showSpinner = false;
            }
        } catch (error) {
            this.error = error;
            this.showSpinner = false;
        }
    }

    resizeImg(imgDataUrl) {

        let targetWidth = this.imageMaxWidth || 800;
        let targetHeight = this.imageMaxHeight || 600;

        const degrees = 0;
        const img = new Image();
        img.src = imgDataUrl;

        return new Promise((resolve, reject) => {
            img.onload = () => {
                const imgWidth = img.width;
                const imgHeight = img.height;
                const mode = (this.imageMode || 'resize').toLowerCase();
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
                    resolve(canvasCopy.toDataURL());
                } else {
                    canvas.width = targetWidth;
                    canvas.height = targetHeight;

                    const offsetX = (newWidth - targetWidth) / 2;
                    const offsetY = (newHeight - targetHeight) / 2;

                    canvasContext.clearRect(0, 0, canvas.width, canvas.height);
                    canvasContext.translate(canvas.width / 2, canvas.height / 2);
                    canvasContext.rotate(degrees * Math.PI / 180);
                    canvasContext.drawImage(canvasCopy, -targetWidth / 2 - offsetX, -targetHeight / 2 - offsetY, newWidth, newHeight);
                    resolve(canvas.toDataURL());
                }
            };

            img.onerror = (error) => reject(error);
        });
    }
}