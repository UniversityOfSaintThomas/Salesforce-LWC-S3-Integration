# Salesforce-LWC-S3-Integration

This Cumulus CI project creates a Lightning Web Component that integrates with AWS S3.

To work on this project in a scratch org:
1. [Set up CumulusCI](https://cumulusci.readthedocs.io/en/latest/tutorial.html)
2. Run `cci flow run dev_org --org dev` to deploy this project.
3. Run `cci org browser dev` to open the org in your browser.

## Additional configuration
Much of this set-up was derived from the [from this tutorial](https://oktana.com/guide-integrating-salesforce-aws-s3/).

### Fill in the AWS Access Key and Secret

1. Got to Setup > Named Credentials. Select the "External Credential" tab.
2. Click on "AWS S3 Credential" label
3. Scroll down to Principals and in the "AWS S3 Principal" parameter select edit from the "Actions" dropdown.
4. Enter the "Access Key" ID and the "Access Secret" keys from your AWS account.
5. Click "Save"

### Adding your AWS S3 Bucket Url to Trusted Urls
1. Go to Setup > Named Credentials.
2. Click on the "AWS S3" label.
3. Copy the URL from the "URL" field.
4. Go to Setup > Trusted Urls.
5. Click "New Trusted URL"
6. Enter API Name: "AWS_S3"
7. Paste the URL you copied in set 3 into the URL field.
8. Check the "Active" checkbox.
9. Make sure that "img-src (images)" is checked.
10. Click "Save"

