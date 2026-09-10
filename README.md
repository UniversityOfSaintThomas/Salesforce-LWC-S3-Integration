# Salesforce LWC S3 Integration

A Lightning Web Component that integrates with AWS S3 to display and upload directory images on Salesforce records. Works in both Lightning Experience and Experience Cloud (community) pages.

---

## Project Structure

This repo is split into two parts:

- **`force-app/`** — the reusable, packageable feature: the `awsDirectoryImageController` Apex class, the `awsS3DirectoryImage` LWC (plus its `errorPanel`/`ldsUtils` dependencies), the Named Credential, External Credential, CSP Trusted Site, and permission set. This is the part intended to be packaged and reused across other Salesforce projects/orgs.
- **`unpackaged/config/dev-demo/`** — Contact-specific example configuration (custom fields, page layouts, FlexiPages, and a record-creation Flow) that exists only to showcase the feature on a Contact record in this repo's scratch org. Deployed separately via the `deploy_dev_config` CumulusCI task, not part of the packaged feature.

If you're integrating this feature into another repo, you only need what's under `force-app/`.

---

## How It Works

The LWC calls an Apex controller (`awsDirectoryImageController`) which makes authenticated callouts to AWS S3 via a Named Credential. The component can:
- **Read** — look up an existing S3 object by a hashed filename prefix and return its URL
- **Write** — upload a new image to S3 and update a field on the record with the image URL

The controller uses `ConnectApi.NamedCredentials.getNamedCredential()` to read the bucket URL from the Named Credential. This API requires the **API Enabled** user permission, which is included in the permission set.

All S3 callouts (list, delete, upload) happen before the single DML update that writes the new image link to the record. This ordering is required — Salesforce does not allow a callout after uncommitted DML in the same transaction, and doing it in the other order throws `"You have uncommitted work pending. Please commit or rollback before calling out."`

---

## Initial Setup (Scratch Org)

1. [Set up CumulusCI](https://cumulusci.readthedocs.io/en/latest/tutorial.html)
2. Run `cci flow run dev_org --org dev` to deploy this project (this deploys `force-app/`, the demo config under `unpackaged/config/dev-demo/`, and assigns both the `AWS_S3_Directory_Image` and `AWS_S3_Directory_Image_Developer_Fields` permission sets to System Administrators)
3. Run `cci org browser dev` to open the org in your browser
4. Complete the manual post-deploy steps below

---

## Post-Deploy Configuration

### 1. Set the S3 Bucket URL

The Named Credential and CSP Trusted Site both ship with a placeholder URL (`https://REPLACE_WITH_YOUR_BUCKET.s3.REPLACE_WITH_REGION.amazonaws.com`) since the actual bucket URL is different for every org/user of this feature. After deploying, update both to point at your real bucket:

1. **Setup → Named Credentials** → click **AWS S3 Directory Image** → edit the **Url** parameter → enter your bucket's URL (`https://<your-bucket-name>.s3.<region>.amazonaws.com`) → **Save**
2. **Setup → Trusted URLs** → click **AWS_S3_Directory_Image** → edit **URL** → enter the same bucket URL → confirm **img-src (images)** is checked → **Save**

Both must point at the **same** bucket and region, or image uploads/lookups will fail.

---

### 2. Enter the AWS Access Key and Secret

The AWS credentials are stored in the External Credential's Named Principal and are **not deployed** (they contain secrets). You must enter them manually after each deploy.

1. Go to **Setup → Named Credentials → External Credentials tab**
2. Click **AWS S3 Directory Image Credential**
3. Under **Principals**, find **AWS S3 Directory Image Principal** and click **Edit** from the Actions dropdown
4. Enter the **Access Key** and **Access Secret** from your AWS IAM account
5. Click **Save**

> **Principal Type must be "Named Principal"** — this is critical. A Named Principal stores one shared set of credentials used by all users who have the permission set. If the principal type is "Per User", each user must individually authenticate, which is impractical for community users. The metadata in this repo deploys a Named Principal (`<parameterType>NamedPrincipal</parameterType>`).

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

## Permission Set: AWS S3 Directory Image Developer Fields (dev-only)

`unpackaged/config/dev-demo/permissionsets/AWS_S3_Directory_Image_Developer_Fields.permissionset-meta.xml` grants Read/Edit field-level security on the three Contact demo fields (`Directory_Image__c`, `Business_Directory_Image__c`, `Business_Directory_Person_Image__c`) used to showcase the component in this repo's scratch org.

This is **not** part of the packaged feature — it exists purely so developers working in this scratch org don't have to manually grant FLS on the demo fields every time they rebuild the org. It's deployed via `deploy_dev_config` and assigned to System Administrators via `deploy_permission_set`, alongside `AWS_S3_Directory_Image`, whenever `cci flow run dev_org` or `cci flow run config_dev` runs.

If you're integrating this feature into your own object/field, you don't need this permission set — see [Field-Level Security on the Target Image Field](#field-level-security-on-the-target-image-field) below for what your own permission set or profile needs to grant instead.

---

## Field-Level Security on the Target Image Field

The `imageField` passed into the component (e.g., `Directory_Image__c`) is **not** covered by the `AWS_S3_Directory_Image` permission set — the component is generic and can point at any field on any object, so field-level security for that field must be granted separately by whoever configures the component for a given use case.

As of API version 67.0, Apex database operations run in **user mode by default** (previously system mode). This means `awsDirectoryImageController` now automatically enforces the running user's field-level security and object permissions on the target image field:

- The running user needs **Read** access on `imageField` — the controller queries it before updating.
- The running user needs **Edit** access on `imageField` — the controller writes the S3 URL (or clears it on delete) via DML.

If either permission is missing, the update will fail with an insufficient-access error rather than silently succeeding or being skipped. Make sure whoever is assigned to interact with this LWC has both Read and Edit field-level security on the field configured for `imageField`, in addition to the `AWS_S3_Directory_Image` permission set.

In this repo's scratch org, the `AWS_S3_Directory_Image_Developer_Fields` permission set (see above) already grants this for the demo Contact fields — you only need to grant it yourself for a field/object you configure on your own.

---

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `We couldn't access the credential(s). You might not have the required permissions, or the external credential "AWS_S3_Directory_Image_Credential" might not exist.` | User is missing the permission set, or the External Credential Principal has no credentials entered | Assign the `AWS_S3_Directory_Image` permission set; verify Access Key and Secret are entered on the principal |
| `Insufficient Privileges: This feature is not currently enabled for this user.` | User is missing the `ApiEnabled` permission (required for `ConnectApi.NamedCredentials`) | Ensure the permission set is assigned — it includes `ApiEnabled` |
| Images visible in Lightning but not in community | Community user missing the permission set assignment | Assign `AWS_S3_Directory_Image` to the community user |
| `Named Credential Id=null` in debug logs | Per User principal with no user-linked credentials | Switch the External Credential principal type to Named Principal (should already be correct per this repo's metadata) |
| `NoSuchBucket` / `AWS S3 request failed: received status 404` | The Named Credential's `Url` parameter is still the placeholder value, or points at a bucket that doesn't exist | Complete [Post-Deploy Configuration step 1](#1-set-the-s3-bucket-url) — update both the Named Credential and CSP Trusted Site with your real bucket URL |
| `A record Id is required.` / `A target image field is required.` | The component was invoked without a valid `recordId` or `imageField` (e.g. misconfigured on the page, or called directly with missing params) | Confirm the component's `record-id` and `image-field` design attributes are set on the FlexiPage/page layout |
| `Unsupported file type. Only JPG, GIF, and PNG images are allowed.` | The uploaded file's content type isn't one of `image/jpeg`, `image/jpg`, `image/gif`, `image/png` | This is enforced server-side (not just the file picker's `accept` filter) since client-side validation can be bypassed; have the user upload a supported image format |
| `The image field "X" does not exist on Y.` | `imageField` doesn't match an actual field API name on the target object | Fix the `image-field` value on the component to a valid field API name |
| `You do not have permission to update the image field on this record.` | The running user lacks Edit field-level security on `imageField` | Grant Edit FLS on that field — see [Field-Level Security on the Target Image Field](#field-level-security-on-the-target-image-field) |
