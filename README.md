# Salesforce LWC S3 Integration

A Lightning Web Component that integrates with AWS S3 to display and upload directory images on Salesforce records. Works in both Lightning Experience and Experience Cloud (community) pages.

---

## How It Works

The LWC calls an Apex controller (`awsDirectoryImageController`) which makes authenticated callouts to AWS S3 via a Named Credential. The component can:
- **Read** — look up an existing S3 object by a hashed filename prefix and return its URL
- **Write** — upload a new image to S3 and update a field on the record with the image URL

The controller uses `ConnectApi.NamedCredentials.getNamedCredential()` to read the bucket URL from the Named Credential. This API requires the **API Enabled** user permission, which is included in the permission set.

---

## Initial Setup (Scratch Org)

1. [Set up CumulusCI](https://cumulusci.readthedocs.io/en/latest/tutorial.html)
2. Run `cci flow run dev_org --org dev` to deploy this project
3. Run `cci org browser dev` to open the org in your browser
4. Complete the manual post-deploy steps below

---

## Post-Deploy Configuration

### 1. Enter the AWS Access Key and Secret

The AWS credentials are stored in the External Credential's Named Principal and are **not deployed** (they contain secrets). You must enter them manually after each deploy.

1. Go to **Setup → Named Credentials → External Credentials tab**
2. Click **AWS S3 Directory Image Credential**
3. Under **Principals**, find **AWS S3 Directory Image Principal** and click **Edit** from the Actions dropdown
4. Enter the **Access Key** and **Access Secret** from your AWS IAM account
5. Click **Save**

> **Principal Type must be "Named Principal"** — this is critical. A Named Principal stores one shared set of credentials used by all users who have the permission set. If the principal type is "Per User", each user must individually authenticate, which is impractical for community users. The metadata in this repo deploys a Named Principal (`<parameterType>NamedPrincipal</parameterType>`).

---

### 2. Add the S3 Bucket URL to Trusted URLs

The browser must be allowed to load images from S3. The CSP Trusted Site is deployed automatically, but verify it exists:

1. Go to **Setup → Trusted URLs**
2. Confirm **AWS_S3_Directory_Image** is listed and active, with **img-src (images)** checked
3. If missing, create it:
   - **API Name**: `AWS_S3_Directory_Image`
   - **URL**: `https://<your-bucket-name>.s3.<region>.amazonaws.com`
   - **Active**: checked
   - **img-src (images)**: checked

---

## Permission Set: AWS S3 Directory Image

The `AWS_S3_Directory_Image` permission set grants users everything required for the LWC to function. It contains four grants:

| What | Why |
|------|-----|
| **Apex Class Access** — `awsDirectoryImageController` | Allows the LWC to invoke the controller via `@AuraEnabled` methods. |
| **External Credential Principal Access** — `AWS_S3_Directory_Image_Credential - AWS S3 Directory Image Principal` | Authorizes the user to make callouts using the Named Credential. Without this, the callout fails with `"We couldn't access the credential(s)"`. Because the principal is a Named Principal, no per-user authentication step is needed. |
| **Object Read Access** — `UserExternalCredential` | Required for Salesforce to verify the user's credential principal access at callout time. |
| **User Permission** — `ApiEnabled` | Required for `ConnectApi.NamedCredentials.getNamedCredential()` to succeed. Without this, community users get `"Insufficient Privileges: This feature is not currently enabled for this user."` This is the key permission needed for Experience Cloud users. |

### Assign the permission set to a user

1. Go to **Setup → Users → [User Name]**
2. Click **Permission Set Assignments → Edit Assignments**
3. Add **AWS S3 Directory Image**
4. Click **Save**

This applies to both internal Lightning Experience users and Experience Cloud (community) users — no additional profile-level changes are needed.

---

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `We couldn't access the credential(s). You might not have the required permissions, or the external credential "AWS_S3_Directory_Image_Credential" might not exist.` | User is missing the permission set, or the External Credential Principal has no credentials entered | Assign the `AWS_S3_Directory_Image` permission set; verify Access Key and Secret are entered on the principal |
| `Insufficient Privileges: This feature is not currently enabled for this user.` | User is missing the `ApiEnabled` permission (required for `ConnectApi.NamedCredentials`) | Ensure the permission set is assigned — it includes `ApiEnabled` |
| Images visible in Lightning but not in community | Community user missing the permission set assignment | Assign `AWS_S3_Directory_Image` to the community user |
| `Named Credential Id=null` in debug logs | Per User principal with no user-linked credentials | Switch the External Credential principal type to Named Principal (should already be correct per this repo's metadata) |
