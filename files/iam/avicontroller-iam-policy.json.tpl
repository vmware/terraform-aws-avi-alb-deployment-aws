{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "iam:GetPolicy",
                "iam:GetPolicyVersion",
                "iam:ListPolicyVersions"
            ],
            "Resource": [
                "arn:${awsPartition}:iam::*:role/AviController-Refined-Role",
                "arn:${awsPartition}:iam::*:policy/AviController*"
            ]
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "iam:GetInstanceProfile",
                "iam:GetRole",
                "iam:GetRolePolicy",
                "iam:ListAttachedRolePolicies",
                "iam:ListRolePolicies"
            ],
            "Resource": [
                "arn:${awsPartition}:iam::*:instance-profile/AviController-Refined-Role",
                "arn:${awsPartition}:iam::*:instance-profile/*_avi_instance_profile",
                "arn:${awsPartition}:iam::*:policy/AviController*",
                "arn:${awsPartition}:iam::*:role/vmimport",
                "arn:${awsPartition}:iam::*:role/AviController-Refined-Role"
            ]
        },
        {
            "Sid": "VisualEditor2",
            "Effect": "Allow",
            "Action": [
                "iam:GetPolicy",
                "iam:GetPolicyVersion",
                "iam:GetRole",
                "iam:GetRolePolicy",
                "iam:ListAttachedRolePolicies",
                "iam:ListPolicies",
                "iam:ListRolePolicies",
                "iam:ListRoles",
                "iam:ListAccountAliases",
                "iam:ListAttachedUserPolicies",
                "iam:ListAttachedGroupPolicies",
                "iam:GetUserPolicy",
                "iam:GetGroupPolicy",
                "iam:ListUserPolicies",
                "iam:ListgroupPolicies"
            ],
            "Resource": "*"
        }
    ]
}