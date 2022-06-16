locals {
    deploy_cross_account_access = {
        "development": true
        "qa": true
        "integration": true
        "preprod": false
        "production": false
        "management-dev": false
        "management": false
    }

    cross_account_roles = [ for env, account in local.account : "arn:aws:iam::${account}:role/${data.terraform_remote_state.internal_compute.outputs.emr_instance_role.id}" if local.deploy_cross_account_access[env] ]
}