# Terraform Cloud / Terraform Enterprise API Demo

Terraform Cloud (TFC) and Terraform Enterprise (TFE) afford us three workflows for managing Terraform runs:
* A UI/VCS-driven workflow, where runs are initiated via the UI or by pushing or merging changes to the version control system (VCS) repository to which the workspace in question is connected.
* A CLI-driven workflow, where runs are initiated via the Terraform command line interface (CLI), but are executed in Terraform Cloud, enabling us to leverage its state management, governance, etc.
* An API-driven workflow, ideal for use by continuous integration (CI) systems and in situations where Terraform Cloud cannot be connected to the VCS where the Terraform code is stored.

We're going to walk through portions of the Terraform Cloud [API](https://www.terraform.io/docs/cloud/api/index.html) below. For a complete reference on the API, please refer to the [API documentation](https://www.terraform.io/docs/cloud/api/index.html).

## Bearer Tokens

We interact with the TFC/TFE API by authenticating using a bearer token. There are three types of bearer tokens that can be used in calling the API.
* User token - each Terraform Cloud user can have any number of API tokens.
* Team token - each team can have one API token that can be used for making calls to execute a Terraform plans and applies.
* Organization token - each organization can have one API token that is intended for automating the management of teams and workspaces.

What you are able to do with a token is governed by the privileges afforded to the entity to which that token belongs.

We will use an Org token and Team token in our demo.

--------------------------------------------------------------------------------

## Environment Variables

These are not required for use of the API, but we will use `curl` to make API calls in our demo, and setting some environment variables will lend to the reuse of the code.

### VAULT_TFE_KV

The Terrraform bearer token(s) should be stored securely. HashiCorp [Vault](https://vaultproject.io) enables us to centralize the storage of secrets and obtain access to those secrets only after successfully authenticating and authorizing access to those secrets. Access to secrets in Vault is path based, and `VAULT_TFE_KV` indicates the path where we will find our tokens.

```
export VAULT_TFE_KV=app.terraform.io/khemani-demo
```

### TFE_TEAM_TOKEN

`TFE_TEAM_TOKEN` will house the Team token for doing our Terraform plans and applies.

```
export TFE_TEAM_TOKEN=$(vault \
  kv get -field=TFE_TEAM_TOKEN kv/tfe/${VAULT_TFE_KV})
```

### TFE_ORG_TOKEN

`TFE_ORG_TOKEN` will house the Org token managing our organization, teams and workspaces.

```
export TFE_ORG_TOKEN=$(vault \
  kv get -field=TFE_ORG_TOKEN kv/tfe/${VAULT_TFE_KV})
```

### TFE_ORG
`TFE_ORG` is the name of your TFC/TFE organization.

```
export TFE_ORG=$(vault \
  kv get -field=TFE_ORG kv/tfe/${VAULT_TFE_KV})
```

### TFE_ADDR
`TFE_ADDR` indicates our TFC/TFE endpoint address.

```
export TFE_ADDR=$(vault \
  kv get -field=TFE_ADDR kv/tfe/${VAULT_TFE_KV})
```

### VCS_OAUTH_TOKEN_ID
`VCS_OAUTH_TOKEN_ID` is our VCS OAuth Token ID. Please note that this jq assumes there is one VCS configured in TFE.

```
export VCS_OAUTH_TOKEN_ID=$(curl -s \
  --header "Authorization: Bearer $TFE_ORG_TOKEN" \
  ${TFE_ADDR}/api/v2/organizations/${TFE_ORG}/oauth-clients | \
  jq -r '.data[].relationships | {"oauth-tokens"} | ."oauth-tokens"."data"[].id')
```

Let's see what our environment variables look like.

```
echo $VAULT_TFE_KV

echo $TFE_TEAM_TOKEN

echo $TFE_ORG_TOKEN

echo $TFE_ORG

echo $TFE_ADDR

echo $VCS_OAUTH_TOKEN_ID
```

e.g.
```
$ echo $VAULT_TFE_KV
app.terraform.io/tfc-demo

$ echo $TFE_TEAM_TOKEN
abcdefghijklmn.atlasv1.abcdefghijklmnopqrstuvwxyz01234456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcd

$ echo $TFE_ORG_TOKEN
abcdefghijklmn.atlasv1.abcdefghijklmnopqrstuvwxyz01234456789ABCDEFGHIJKLMNOPQRSTUVWXYZabce

$ echo $TFE_ORG
tfc-demo

$ echo $TFE_ADDR
https://app.terraform.io

$ echo $VCS_OAUTH_TOKEN_ID
ot-abcdefghijklmnop
```

--------------------------------------------------------------------------------

## Workspaces

### Create a VCS-connected workspace
Let's create a VCS-connected workspace for use in a UI/VCS-driven workflow.

This is useful when the Terraform runs will not be driven by a CI system; rather the CI system is responsible for creating the workspace requested by a team that will then merge changes into the VCS repo associated with that workspace to initiate Terraform runs.

* Reference: https://www.terraform.io/docs/cloud/api/workspaces.html#create-a-workspace

* API Call: `POST /organizations/:organization_name/workspaces`

#### Additional environment variables

Let's set the following environment variables to facilitate our work.

```
export VCS_WORKSPACE_NAME="vcs-driven-workspace"
export TF_VERSION="0.14.3"
export WORKING_DIRECTORY=""
export VCS_REPO="ykhemani/tfe-demo-aws"
export VCS_BRANCH="" # blank for default
```

Let's define our JSON payload for our API call, referencing the aforementioned variables.

```
cat <<EOF > payload.json
{
  "data": {
    "attributes": {
      "name": "${VCS_WORKSPACE_NAME}",
      "terraform_version": "${TF_VERSION}",
      "working-directory": "${WORKING_DIRECTORY}",
      "vcs-repo": {
        "identifier": "${VCS_REPO}",
        "oauth-token-id": "${VCS_OAUTH_TOKEN_ID}",
        "branch": "${VCS_BRANCH}",
        "default-branch": true
      }
    },
    "type": "workspaces"
  }
}
EOF
```

Let's make the API call using our Org token.

```
curl -s \
  --header "Authorization: Bearer $TFE_ORG_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @payload.json \
  ${TFE_ADDR}/api/v2/organizations/${TFE_ORG}/workspaces | jq -r .
```

### Create a workspace without a VCS connection

Let's create a workspace without specifying a VCS connection.

This is useful when the Terraform runs are going to be initiated by a CI system.

* Reference: https://www.terraform.io/docs/cloud/api/workspaces.html#create-a-workspace

* API Call: `POST /organizations/:organization_name/workspaces`

#### Additional environment variables

Let's set the following environment variable to facilitate our work.

```
export API_WORKSPACE_NAME="api-driven-workspace"
```

Let's define our JSON payload for our API call, referencing the aforementioned variables.

```
cat <<EOF > payload.json
{
  "data": {
    "attributes": {
      "name": "${API_WORKSPACE_NAME}",
      "auto-apply": true
    },
    "type": "workspaces"
  }
}
EOF
```

Let's make the API call using our Org token.

```
curl -s \
  --header "Authorization: Bearer $TFE_ORG_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @payload.json \
  ${TFE_ADDR}/api/v2/organizations/${TFE_ORG}/workspaces | jq -r .
```

### List workspaces

Let's list the workspaces in our organization.

* Reference: https://www.terraform.io/docs/cloud/api/workspaces.html#list-workspaces

* API Call: `GET /organizations/:organization_name/workspaces`

```
curl -s \
  --header "Authorization: Bearer $TFE_ORG_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  ${TFE_ADDR}/api/v2/organizations/${TFE_ORG}/workspaces | jq -r .
```

### Show workspace using workspace name

Let's look at a workspace. We can reference the workspace name or the workspace ID.

Using the organization and workspace names:

* Reference: https://www.terraform.io/docs/cloud/api/workspaces.html#show-workspace

* API Call: `GET /organizations/:organization_name/workspaces/:name`

Let's make the API call using our Org token.

```
curl -s \
  --header "Authorization: Bearer $TFE_ORG_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  ${TFE_ADDR}/api/v2/organizations/${TFE_ORG}/workspaces/${VCS_WORKSPACE_NAME} | jq -r .
```

### Show workspace using workspace ID

Using the workspace ID:

* Reference: https://www.terraform.io/docs/cloud/api/workspaces.html#show-workspace

* API Call: `GET /workspaces/:workspace_id`

Let's obtain the workspace ID if we don't already have it.

```
export WORKSPACE_ID=$(curl -s \
  --header "Authorization: Bearer $TFE_ORG_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  ${TFE_ADDR}/api/v2/organizations/${TFE_ORG}/workspaces | \
  jq -r ".data[] | select (.attributes.name==\"${API_WORKSPACE_NAME}\") | .id")
```

Let's examine the workspace ID.

```
echo $WORKSPACE_ID
```

Let's make the API call using our Org token.

```
curl -s \
  --header "Authorization: Bearer $TFE_ORG_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  ${TFE_ADDR}/api/v2//workspaces/${WORKSPACE_ID} | jq -r .
```

--------------------------------------------------------------------------------

## Workspace variables

### Terraform Variables

Let's define Terraform variables required for our VCS-driven workspace.

* Reference: https://www.terraform.io/docs/cloud/api/variables.html#create-a-variable

* API Call: `POST /workspaces/:workspace_id/vars`

Let's obtain our workspace ID if we don't already have it.

```
export WORKSPACE_ID=$(curl -s \
  --header "Authorization: Bearer $TFE_ORG_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  ${TFE_ADDR}/api/v2/organizations/${TFE_ORG}/workspaces | \
  jq -r ".data[] | select (.attributes.name==\"${VCS_WORKSPACE_NAME}\") | .id")
```

Let's see what that looks like.

```
echo $WORKSPACE_ID
```

Let's set the following environment variables to facilitate setting our variables.

```
export VARIABLE_0_KEY="instance_type"
export VARIABLE_0_VALUE="t2.small"
export VARIABLE_0_DESCRIPTION="AWS Instance size"
```

Let's create our JSON payload, referencing the aforementioned environment variables.

```
cat <<EOF > payload.json
{
  "data": {
    "type":"vars",
    "attributes": {
      "key":"${VARIABLE_0_KEY}",
      "value":"${VARIABLE_0_VALUE}",
      "description":"${VARIABLE_0_DESCRIPTION}",
      "category":"terraform",
      "hcl":false,
      "sensitive":false
    }
  }
}
EOF
```

Let's make the API call using our Team token.

```
curl -s \
  --header "Authorization: Bearer $TFE_TEAM_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @payload.json \
  ${TFE_ADDR}/api/v2/workspaces/${WORKSPACE_ID}/vars | jq -r .
```

Let's repeat for the following Terraform variable.

```
export VARIABLE_1_KEY="aws_region"
export VARIABLE_1_VALUE="us-west-2"
export VARIABLE_1_DESCRIPTION="AWS Region"
```

```
cat <<EOF > payload.json
{
  "data": {
    "type":"vars",
    "attributes": {
      "key":"${VARIABLE_1_KEY}",
      "value":"${VARIABLE_1_VALUE}",
      "description":"${VARIABLE_1_DESCRIPTION}",
      "category":"terraform",
      "hcl":false,
      "sensitive":false
    }
  }
}
EOF
```

```
curl -s \
  --header "Authorization: Bearer $TFE_TEAM_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @payload.json \
  ${TFE_ADDR}/api/v2/workspaces/${WORKSPACE_ID}/vars | jq -r .
```

### Environment Variables for our Terraform Run

Our demo will provision resources in AWS. The AWS provider requires the Terraform run to authenticate. This can be done in a number of ways:
* via Terraform variables passed to the provider stanza.
* via environment variables used in our Terraform run.
* via short-lived credentials obtained via the Vault provider.

We are going to set our AWS credentials via environment variables. Terraform Cloud enables us to mark Terraform as well as Environment Variables as sensitve such that they are write-only with the result that someone with the required privileges can update the variable, but they cannot read it. Note that Terraform Cloud encrypts all variables, whether they are marked sensitive or not, using the Vault Transit secret engine.

Let's set the following environment variables to facilitate setting our variables. This environment variable is referenced in our `curl` (API) call; it is not the environment variable we are defining in our workspace.

```
export VARIABLE_2_KEY="AWS_ACCESS_KEY_ID"
```

Let's define our JSON payload. Please note that we are referencing an existing environment variable for the value.

```
cat <<EOF > payload.json
{
  "data": {
    "type":"vars",
    "attributes": {
      "key":"${VARIABLE_2_KEY}",
      "value":"${AWS_ACCESS_KEY_ID}",
      "category":"env",
      "hcl":false,
      "sensitive":true
    }
  }
}
EOF
```

Let's make the API call using our Team token.

```
curl -s \
  --header "Authorization: Bearer $TFE_TEAM_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @payload.json \
  ${TFE_ADDR}/api/v2/workspaces/${WORKSPACE_ID}/vars | jq -r .
```

Let's repeat for the following environment variables.

```
export VARIABLE_3_KEY="AWS_SECRET_ACCESS_KEY"
```

```
cat <<EOF > payload.json
{
  "data": {
    "type":"vars",
    "attributes": {
      "key":"${VARIABLE_3_KEY}",
      "value":"${AWS_SECRET_ACCESS_KEY}",
      "category":"env",
      "hcl":false,
      "sensitive":true
    }
  }
}
EOF
```

```
curl -s \
  --header "Authorization: Bearer $TFE_TEAM_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @payload.json \
  ${TFE_ADDR}/api/v2/workspaces/${WORKSPACE_ID}/vars | jq -r .
```

One more:

```
export VARIABLE_3_KEY="AWS_SESSION_TOKEN"
```

```
cat <<EOF > payload.json
{
  "data": {
    "type":"vars",
    "attributes": {
      "key":"${VARIABLE_3_KEY}",
      "value":"${AWS_SESSION_TOKEN}",
      "category":"env",
      "hcl":false,
      "sensitive":true
    }
  }
}
EOF
```

```
curl -s \
  --header "Authorization: Bearer $TFE_TEAM_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @payload.json \
  ${TFE_ADDR}/api/v2/workspaces/${WORKSPACE_ID}/vars | jq -r .
```

--------------------------------------------------------------------------------

### Workspace variables for our API-driven workspace

```
export WORKSPACE_ID=$(curl -s \
  --header "Authorization: Bearer $TFE_ORG_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  ${TFE_ADDR}/api/v2/organizations/${TFE_ORG}/workspaces | \
  jq -r ".data[] | select (.attributes.name==\"${API_WORKSPACE_NAME}\") | .id")
```

```
echo $WORKSPACE_ID
```

```
export VARIABLE_0_KEY="instance_type"
export VARIABLE_0_VALUE="t2.small"
export VARIABLE_0_DESCRIPTION="AWS Instance size"
```

```
cat <<EOF > payload.json
{
  "data": {
    "type":"vars",
    "attributes": {
      "key":"${VARIABLE_0_KEY}",
      "value":"${VARIABLE_0_VALUE}",
      "description":"${VARIABLE_0_DESCRIPTION}",
      "category":"terraform",
      "hcl":false,
      "sensitive":false
    }
  }
}
EOF
```

```
curl -s \
  --header "Authorization: Bearer $TFE_TEAM_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @payload.json \
  ${TFE_ADDR}/api/v2/workspaces/${WORKSPACE_ID}/vars | jq -r .
```

One more:

```
export VARIABLE_1_KEY="aws_region"
export VARIABLE_1_VALUE="us-west-2"
export VARIABLE_1_DESCRIPTION="AWS Region"
```

```
cat <<EOF > payload.json
{
  "data": {
    "type":"vars",
    "attributes": {
      "key":"${VARIABLE_1_KEY}",
      "value":"${VARIABLE_1_VALUE}",
      "description":"${VARIABLE_1_DESCRIPTION}",
      "category":"terraform",
      "hcl":false,
      "sensitive":false
    }
  }
}
EOF
```

```
curl -s \
  --header "Authorization: Bearer $TFE_TEAM_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @payload.json \
  ${TFE_ADDR}/api/v2/workspaces/${WORKSPACE_ID}/vars | jq -r .
```

Let's define our sensitive environment variables.

```
export VARIABLE_2_KEY="AWS_ACCESS_KEY_ID"
```

```
cat <<EOF > payload.json
{
  "data": {
    "type":"vars",
    "attributes": {
      "key":"${VARIABLE_2_KEY}",
      "value":"${AWS_ACCESS_KEY_ID}",
      "category":"env",
      "hcl":false,
      "sensitive":true
    }
  }
}
EOF
```

```
curl -s \
  --header "Authorization: Bearer $TFE_TEAM_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @payload.json \
  ${TFE_ADDR}/api/v2/workspaces/${WORKSPACE_ID}/vars | jq -r .
```

```
export VARIABLE_3_KEY="AWS_SECRET_ACCESS_KEY"
```

```
cat <<EOF > payload.json
{
  "data": {
    "type":"vars",
    "attributes": {
      "key":"${VARIABLE_3_KEY}",
      "value":"${AWS_SECRET_ACCESS_KEY}",
      "category":"env",
      "hcl":false,
      "sensitive":true
    }
  }
}
EOF
```

```
curl -s \
  --header "Authorization: Bearer $TFE_TEAM_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @payload.json \
  ${TFE_ADDR}/api/v2/workspaces/${WORKSPACE_ID}/vars | jq -r .
```

```
export VARIABLE_4_KEY="AWS_SESSION_TOKEN"
```

```
cat <<EOF > payload.json
{
  "data": {
    "type":"vars",
    "attributes": {
      "key":"${VARIABLE_4_KEY}",
      "value":"${AWS_SESSION_TOKEN}",
      "category":"env",
      "hcl":false,
      "sensitive":true
    }
  }
}
EOF
```

```
curl -s \
  --header "Authorization: Bearer $TFE_TEAM_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @payload.json \
  ${TFE_ADDR}/api/v2/workspaces/${WORKSPACE_ID}/vars | jq -r .
```

--------------------------------------------------------------------------------

## Create Terraform Configuration tar-gzip file

Let's obtain our Terraform configuration and generate a tar-gzip file that we will upload to Terraform Cloud.

We have a sample configuration in the [tf_config](tf_config) directory.

```
export CONTENT_DIRECTORY=./tf_config

export UPLOAD_FILE_NAME="./content-$(date +%s).tar.gz"

tar -zcvf "$UPLOAD_FILE_NAME" -C "$CONTENT_DIRECTORY" .
```

## Create a configuration version

Let's generate a configuration version. This will provide us with the URL that we will use to upload the Terraform configuration.

* Reference: https://www.terraform.io/docs/cloud/api/configuration-versions.html#create-a-configuration-version

* API Call: `POST /workspaces/:workspace_id/configuration-versions`

```
export WORKSPACE_ID=$(curl -s \
  --header "Authorization: Bearer $TFE_ORG_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  ${TFE_ADDR}/api/v2/organizations/${TFE_ORG}/workspaces | \
  jq -r ".data[] | select (.attributes.name==\"${API_WORKSPACE_NAME}\") | .id")
```

```
echo $WORKSPACE_ID
```

Let's generate our JSON payload.

```
cat <<EOF > create_config_version.json
{
  "data": {
    "type": "configuration-versions"
  }
}
EOF
```

Let's obtain our upload URL by making the API call.

```
UPLOAD_URL=($(curl -s \
  --header "Authorization: Bearer $TFE_TEAM_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @create_config_version.json \
  ${TFE_ADDR}/api/v2/workspaces/${WORKSPACE_ID}/configuration-versions \
  | jq -r '.data.attributes."upload-url"' ) )
```

```
echo ${UPLOAD_URL}
```

## Upload Configuration

Next, let's upload the configuration.

```
curl \
  --header "Content-Type: application/octet-stream" \
  --request PUT \
  --data-binary @"${UPLOAD_FILE_NAME}" \
  ${UPLOAD_URL}
```

Because we configured our workspace to auto-apply, we don't need to create a run. Otherwise, we could POST to the `/runs` API to create a run.

--------------------------------------------------------------------------------
###### End
