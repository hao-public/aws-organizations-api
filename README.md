# aws-organizations-api
API for AWS Organizations

## Useful API methods to map


HTTP methods: get, post, put, patch, delete, head, options, and trace.


## Accounts resource

| Resource | HTTP Verb | Path | AWS Method |
|---|---|---|---|
| accounts | POST | /{token}/{account-name}{email}/{iam-user-access-to-billing}/{role-name} | CreateAccount |
| accounts | GET | /{token}/{account-id} | DescribeAccount |
| accounts | GET | /{token} | ListAccounts |
| accounts | GET | /{token}/{parent-id} | ListAccountsForParent |
| accounts | PATCH | /{token}/{account-id}/{destination-parent-id}/{source-parent-id} | MoveAccount |
| accounts | DELETE | /{token}/{account-id} | RemoveAccountFromOrganization |
| create-account-status | GET | /{token}/{id} | DescribeCreateAccountStatus |
| create-account-status | GET | /{token} | ListCreateAccountStatus |


[AWS Reference: API operations](https://docs.aws.amazon.com/organizations/latest/APIReference/action-reference.html)

### Operations you can call from only the organization's management account

- AttachPolicy 
- CancelHandshake 
- CreateAccount (POST)
- <del>CreateGovCloudAccount
- <del>CreateOrganization
- CreateOrganizationalUnit
- CreatePolicy
- <del>DeleteOrganization
- DeleteOrganizationalUnit
- DeletePolicy
- <del>DeregisterDelegatedAdministrator
- <del>DisableAWSServiceAccess
- <del>DisablePolicyType
- <del>EnableAllFeatures
- <del>EnableAWSServiceAccess
- EnablePolicyType
- InviteAccountToOrganization
- MoveAccount
- <del>RegisterDelegatedAdministrator
- RemoveAccountFromOrganization
- TagResource
- UntagResource
- UpdateOrganizationalUnit
- UpdatePolicy

### Operations you can call from only the organization's management account or a member account designated as a delegated administrator
- DescribeAccount
- DescribeCreateAccountStatus
- DescribeOrganizationalUnit
- DescribePolicy
- ListAccounts
- ListAccountsForParent
- ListChildren
- ListCreateAccountStatus
- ListHandshakesForOrganization
- ListOrganizationalUnitsForParent
- ListParents
- ListPolicies
- ListPoliciesForTarget
- ListRoots
- ListTagsForResource
- ListTargetsForPolicy

### Operations you can call from only a member account in the organization
- AcceptHandshake (can be called from only the account that received the handshake/invitation)
- DeclineHandshake (can be called from only the account that received the handshake/invitation)
- LeaveOrganization

### Operations you can call from any account in the organization
- DescribeHandshake
- DescribeEffectivePolicy (A member account can call this operation only if the TargetId parameter is set to the member account's own ID - it can't target another account.)
- DescribeOrganization
- ListHandshakesForAccount
