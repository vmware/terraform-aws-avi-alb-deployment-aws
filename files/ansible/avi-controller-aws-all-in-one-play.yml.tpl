# Copyright 2022 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0
---
- name: Avi Controller Configuration
  hosts: localhost
  connection: local
  gather_facts: no
  vars:
    avi_credentials:
        controller: "{{ controller_ip[0] }}"
        username: "{{ username }}"
        password: "{{ password }}"
        api_version: "{{ api_version }}"
    username: "admin"
    password: "{{ password }}"
    api_version: ${avi_version}
    cloud_name: "Default-Cloud"
    license_tier: ${license_tier}
    license_key: ${license_key}
    ca_certificates:
      ${ indent(6, yamlencode(ca_certificates))}
    portal_certificate:
      ${ indent(6, yamlencode(portal_certificate))}
    securechannel_certificate:
      ${ indent(6, yamlencode(securechannel_certificate))}
    controller_ip:
      ${ indent(6, yamlencode(controller_ip))}
    controller_names:
      ${ indent(6, yamlencode(controller_names))}
    ansible_become: yes
    ansible_become_password: "{{ password }}"
    aws_partition: ${aws_partition}
    aws_vpc_id: ${vpc_id}
    aws_region: ${aws_region}
    name_prefix: ${name_prefix}
    se_ha_mode: ${se_ha_mode}
    se_instance_type: ${se_instance_type}
%{ if se_ebs_encryption_key_arn != null ~}
    se_ebs_encryption_key_arn : ${se_ebs_encryption_key_arn}
%{ endif ~}
%{ if se_s3_encryption_key_arn != null ~}
    se_s3_encryption_key_arn : ${se_s3_encryption_key_arn}
%{ endif ~}
%{ if create_firewall_rules ~}
    mgmt_security_group: ${mgmt_security_group}
    data_security_group: ${data_security_group}
%{ endif ~}
    controller_ha: ${controller_ha}
%{ if dns_servers != null ~}
    dns_servers:
%{ for item in dns_servers ~}
      - addr: "${item}"
        type: "V4"
%{ endfor ~}
    dns_search_domain: ${dns_search_domain}
%{ endif ~}
    ntp_servers:
%{ for item in ntp_servers ~}
      - server:
          addr: "${item.addr}"
          type: "${item.type}"
%{ endfor ~}
    email_config:
      ${ indent(6, yamlencode(email_config))}
    route53_integration: ${configure_dns_route_53}
    configure_dns_profile: 
      ${ indent(6, yamlencode(configure_dns_profile))}
    configure_dns_vs:
      ${ indent(6, yamlencode(configure_dns_vs))}
    configure_gslb:
      ${ indent(6, yamlencode(configure_gslb))}
    gslb_user: "gslb-admin"
%{ if avi_upgrade.enabled || register_controller.enabled  ~}
    avi_upgrade:
      enabled: ${avi_upgrade.enabled}
    register_controller:
      enabled: ${register_controller.enabled}
%{ endif ~}
%{ if aws_partition == "aws-us-gov" ~}
    motd: >
      Attention!!

      The use of this system is restricted to authorized users only. Unauthorized
      access, use, or modification of this computer system or of the data contained
      herein or in transit to/from this system constitutes a violation of Title 18,
      United States Code, Section 1030 and state criminal and civil laws. 
      

      These systems and equipment are subject to monitoring to ensure proper performance
      of applicable system and security features. Such monitoring may result in the
      acquisition, recording and analysis of all data being communicated, transmitted,
      processed, or stored in this system by a user, including personal information.


      Evidence of unauthorized use collected during monitoring may be used for
      administrative, criminal, or other adverse action. Unauthorized use may subject
      you to criminal prosecution. Use of this computer system, authorized or
      unauthorized, constitutes consent to monitoring of this system. 

      
      By accessing this information system, the user acknowledges and accepts the
      aforementioned terms and conditions.
%{ endif ~}
  tasks:
    - name: Wait for Controller to become ready
      uri:
        url: "https://localhost/api/initial-data"
        validate_certs: no
        status_code: 200
      register: result
      until: result.status == 200
      retries: 300
      delay: 10
         
    - name: Configure System Configurations
      avi_systemconfiguration:
        avi_credentials: "{{ avi_credentials }}"
        state: present
        default_license_tier: "{{ license_tier }}"
        email_configuration: "{{ email_config }}"
        global_tenant_config:
          se_in_provider_context: true
          tenant_access_to_provider_se: true
          tenant_vrf: false
%{ if dns_servers != null ~}
        dns_configuration:
          server_list: "{{ dns_servers }}"
          search_domain: "{{ dns_search_domain }}"
%{ endif ~}
        ntp_configuration:
          ntp_servers: "{{ ntp_servers }}"        
        portal_configuration:
          allow_basic_authentication: false
          disable_remote_cli_shell: false
          enable_clickjacking_protection: true
          enable_http: true
          enable_https: true
          password_strength_check: true
          redirect_to_https: true
          use_uuid_from_input: false
%{ if aws_partition == "aws-us-gov" ~}
        linux_configuration:
          banner: "{{ motd }}"
%{ endif ~}
        welcome_workflow_complete: true
      until: sysconfig is not failed
      retries: 30
      delay: 5
      register: sysconfig

    - name: Apply Avi License for ENTERPRISE Tier
      avi_api_session:
        avi_credentials: "{{ avi_credentials }}"
        http_method: put
        path: "licensing"
        data:
          serial_key: "{{ license_key }}"
      when: license_tier == "ENTERPRISE" and license_key != ""
      register: license
      ignore_errors: yes

    - name: Delete Trial Avi License when license is added successfully
      avi_api_session:
        avi_credentials: "{{ avi_credentials }}"
        http_method: delete
        path: "licensing/Eval"
      when: license_tier == "ENTERPRISE" and license_key != "" and license.failed != true
      ignore_errors: yes

    - name: Import CA SSL Certificates
      avi_sslkeyandcertificate:
        avi_credentials: "{{ avi_credentials }}"
        name: "{{ item.name }}"
        certificate_base64: true
        certificate:
          certificate: "{{ item.certificate }}"
        format: SSL_PEM
        type: SSL_CERTIFICATE_TYPE_CA
      when: ca_certificates.0.certificate != ""
      ignore_errors: yes
      loop: "{{ ca_certificates }}"

    - name: Import Portal SSL Certificate
      avi_sslkeyandcertificate:
        avi_credentials: "{{ avi_credentials }}"
        name: "{{ name_prefix }}-Portal-Cert"
        certificate_base64: true
        key_base64: true
        key: "{{ portal_certificate.key }}"
        certificate:
          certificate: "{{ portal_certificate.certificate }}"
        key_passphrase: "{{ portal_certificate.key_passphrase | default(omit) }}"
        format: SSL_PEM
        type: SSL_CERTIFICATE_TYPE_SYSTEM
      when: portal_certificate.certificate != ""
      register: portal_cert
      ignore_errors: yes

    - name: Update Portal Cert in System Configuration
      avi_systemconfiguration:
        avi_credentials: "{{ avi_credentials }}"
        state: present
        avi_api_update_method: patch
        avi_api_patch_op: replace
        portal_configuration:
          sslkeyandcertificate_refs:
            - "/api/sslkeyandcertificate?name={{ name_prefix }}-Portal-Cert"
      when: portal_cert is changed
      ignore_errors: yes

    - name: Import Secure Channel SSL Certificate
      avi_sslkeyandcertificate:
        avi_credentials: "{{ avi_credentials }}"
        name: "{{ name_prefix }}-Secure-Channel-Cert"
        certificate_base64: true
        key_base64: true
        key: "{{ securechannel_certificate.key }}"
        certificate:
          certificate: "{{ securechannel_certificate.certificate }}"
        key_passphrase: "{{ securechannel_certificate.key_passphrase | default(omit) }}"
        format: SSL_PEM
        type: SSL_CERTIFICATE_TYPE_SYSTEM
      when: securechannel_certificate.certificate != ""
      register: securechannel_cert

    - name: Update Secure Channel Cert in System Configuration
      avi_systemconfiguration:
        avi_credentials: "{{ avi_credentials }}"
        state: present
        avi_api_update_method: patch
        avi_api_patch_op: replace
        secure_channel_configuration:
          sslkeyandcertificate_refs:
            - "/api/sslkeyandcertificate?name={{ name_prefix }}-Secure-Channel-Cert"
      when: securechannel_cert is changed

    - name: Configure Cloud
      avi_cloud:
        avi_credentials: "{{ avi_credentials }}"
        state: present
        avi_api_update_method: patch
        avi_api_patch_op: replace
        name: "{{ cloud_name }}"
        vtype: CLOUD_AWS
        dhcp_enabled: true
        license_type: "LIC_CORES"
        aws_configuration:
%{ if create_iam ~}
          use_iam_roles: true
%{ else ~}
          access_key_id: "{{ aws_access_key_id }}"
          secret_access_key: "{{ aws_secret_access_key }}"
%{ endif ~}
          region: "{{ aws_region }}"
          asg_poll_interval: 60
          vpc_id: "{{ aws_vpc_id }}"
          route53_integration: "{{ route53_integration }}"
%{ if se_ebs_encryption_key_arn != null ~}
          ebs_encryption:
            master_key: "{{ se_ebs_encryption_key_arn }}"
            mode: "AWS_ENCRYPTION_MODE_SSE_KMS"
%{ endif ~}
%{ if se_s3_encryption_key_arn != null ~}
          s3_encryption:
            master_key: "{{ se_s3_encryption_key_arn }}"
            mode: "AWS_ENCRYPTION_MODE_SSE_KMS"
%{ endif ~}
          zones: 
%{ for zone, mgmt_subnet in se_mgmt_subnets ~}
            - availability_zone: "${zone}"
              mgmt_network_name: "${mgmt_subnet["mgmt_network_name"]}"
              mgmt_network_uuid: "${mgmt_subnet["mgmt_network_uuid"]}"
%{ endfor ~}
      register: avi_cloud
      ignore_errors: yes

    - name: Set Backup Passphrase
      avi_backupconfiguration:
        avi_credentials: "{{ avi_credentials }}"
        state: present
        name: Backup-Configuration
        backup_passphrase: "{{ password }}"
        upload_to_remote_host: false

%{ if se_ha_mode == "active/active" ~}
    - name: Configure SE-Group
      avi_serviceenginegroup:
        avi_credentials: "{{ avi_credentials }}"
        tenant: "admin"
        name: "Default-Group" 
        cloud_ref: "/api/cloud?name={{ cloud_name }}"
        ha_mode: HA_MODE_SHARED_PAIR
        min_scaleout_per_vs: 2
        algo: PLACEMENT_ALGO_PACKED
        buffer_se: "0"
        max_se: "10"
        se_name_prefix: "{{ name_prefix }}"
        accelerated_networking: true
        instance_flavor: "{{ se_instance_type }}"
%{ if create_firewall_rules ~}
        disable_avi_securitygroups: true
        custom_securitygroups_mgmt:
          - "{{ mgmt_security_group }}"
        custom_securitygroups_data:
          - "{{ data_security_group }}"
%{ endif ~}
        realtime_se_metrics:
          duration: "10080"
          enabled: true

%{ endif ~}
%{ if se_ha_mode == "n+m" ~}
    - name: Configure SE-Group
      avi_serviceenginegroup:
        avi_credentials: "{{ avi_credentials }}"
        tenant: "admin"
        name: "Default-Group" 
        state: present
        cloud_ref: "/api/cloud?name={{ cloud_name }}"
        ha_mode: HA_MODE_SHARED
        min_scaleout_per_vs: 1
        algo: PLACEMENT_ALGO_PACKED
        buffer_se: "1"
        max_se: "10"
        se_name_prefix: "{{ name_prefix }}"
        instance_flavor: "{{ se_instance_type }}"
        accelerated_networking: true
%{ if create_firewall_rules ~}
        disable_avi_securitygroups: true
        custom_securitygroups_mgmt:
          - "{{ mgmt_security_group }}"
        custom_securitygroups_data:
          - "{{ data_security_group }}"
%{ endif ~}
        realtime_se_metrics:
          duration: "10080"
          enabled: true

%{ endif ~}
%{ if se_ha_mode == "active/standby" ~}
    - name: Configure SE-Group
      avi_serviceenginegroup:
        avi_credentials: "{{ avi_credentials }}"
        tenant: "admin"
        name: "Default-Group" 
        cloud_ref: "/api/cloud?name={{ cloud_name }}"
        ha_mode: HA_MODE_LEGACY_ACTIVE_STANDBY
        min_scaleout_per_vs: 1
        buffer_se: "0"
        max_se: "2"
        se_name_prefix: "{{ name_prefix }}"
        instance_flavor: "{{ se_instance_type }}"
        accelerated_networking: true
%{ if create_firewall_rules ~}
        disable_avi_securitygroups: true
        custom_securitygroups_mgmt:
          - "{{ mgmt_security_group }}"
        custom_securitygroups_data:
          - "{{ data_security_group }}"
%{ endif ~}
        realtime_se_metrics:
          duration: "10080"
          enabled: true

%{ endif ~}
    - name: Configure DNS Profile
      block:
        - name: Build list for dns_service_domain API field
          set_fact:
            dns_service_domain: "{{ dns_service_domain | default([]) + [{'domain_name': domain, 'pass_through': 'true' }] }}"
          loop: "{{ configure_dns_profile.usable_domains }}"
          loop_control:
            loop_var: domain
          when: configure_dns_profile.type == "AVI"
          

        - name: Create Avi DNS Profile
          avi_ipamdnsproviderprofile:
            avi_credentials: "{{ avi_credentials }}"
            state: present
            name: "Avi_DNS"
            type: "IPAMDNS_TYPE_INTERNAL_DNS"          
            internal_profile:
              dns_service_domain: "{{ dns_service_domain }}"
              ttl: "{{ configure_dns_profile.ttl | default('30') }}"
          register: create_dns_avi
          when: configure_dns_profile.type == "AVI"
        
        - name: Update Cloud Configuration with DNS profile 
          avi_cloud:
            avi_credentials: "{{ avi_credentials }}"
            avi_api_update_method: patch
            avi_api_patch_op: add
            name: "{{ cloud_name }}"
            dns_provider_ref: "{{ create_dns_avi.obj.url }}"
            vtype: CLOUD_AWS
          when: configure_dns_profile.type == "AVI"

        - name: Create AWS Route53 DNS Profile
          avi_ipamdnsproviderprofile:
            avi_credentials: "{{ avi_credentials }}"
            state: present
            name: "AWS_R53_DNS"
            type: "IPAMDNS_TYPE_AWS_DNS"
            aws_profile:
              iam_assume_role: "{{ configure_dns_profile.aws_profile.iam_assume_role }}"
              access_key_id: "{{ configure_dns_profile.aws_profile.access_key_id }}"
              secret_access_key: "{{ configure_dns_profile.aws_profile.secret_access_key }}"
              region: "{{ configure_dns_profile.aws_profile.region }}"
              vpc_id: "{{ configure_dns_profile.aws_profile.vpc_id }}"
              usable_domains: "{{ configure_dns_profile.usable_domains }}"
              ttl: "{{ configure_dns_profile.ttl | default('30') }}"
          register: create_dns_aws
          when: configure_dns_profile.type == "AWS" and route53_integration == false

        - name: Update Cloud Configuration with DNS profile
          avi_cloud:
            avi_credentials: "{{ avi_credentials }}"
            avi_api_update_method: patch
            avi_api_patch_op: add
            name: "{{ cloud_name }}"
            dns_provider_ref: "{{ create_dns_aws.obj.url }}"
            vtype: CLOUD_AWS
          when: configure_dns_profile.type == "AWS" and route53_integration == false
      when: configure_dns_profile.enabled == true
      tags: dns_profile
      ignore_errors: yes
    
    - name: Configure GSLB SE Group and Account
      block:
        - name: Configure GSLB SE-Group
          avi_serviceenginegroup:
            avi_credentials: "{{ avi_credentials }}"
            tenant: "admin"
            name: "g-dns" 
            cloud_ref: "/api/cloud?name={{ cloud_name }}"
            ha_mode: HA_MODE_SHARED_PAIR
            min_scaleout_per_vs: 2
            algo: PLACEMENT_ALGO_PACKED
            buffer_se: "0"
            max_se: "4"
            max_vs_per_se: "1"
            extra_shared_config_memory: 2000
            instance_flavor: "{{ configure_gslb.se_size | default('c5.xlarge') }}"
            se_name_prefix: "{{ name_prefix }}{{ configure_gslb.site_name }}"
            realtime_se_metrics:
              duration: "60"
              enabled: true
          register: gslb_se_group
          when: configure_gslb.create_se_group == true or configure_gslb.create_se_group == "null"

        - name: Create User for GSLB
          avi_user:
            avi_credentials: "{{ avi_credentials }}"
            default_tenant_ref: "/api/tenant?name=admin"
            state: present
            name: "{{ gslb_user }}"
            access:
              - all_tenants: true
                role_ref: "/api/role?name=System-Admin"
            email: "{{ user_email | default(omit) }}"
            user_profile_ref: "/api/useraccountprofile?name=No-Lockout-User-Account-Profile"
            is_superuser: false
            obj_password: "{{ password }}"
            obj_username: "{{ gslb_user }}"
      when: configure_gslb.enabled == true
      tags: gslb

    - name: Configure DNS Virtual Service
      block:
        - name: DNS VS Config | Get AWS Subnet Information
          avi_api_session:
            avi_credentials: "{{ avi_credentials }}"
            http_method: get
            path: "vimgrnwruntime?name={{ configure_dns_vs.subnet_name }}"
          register: dns_vs_subnet

        - name: Create DNS VSVIP
          avi_vsvip:
            avi_credentials: "{{ avi_credentials }}"
            tenant: "admin"
            cloud_ref: "/api/cloud?name={{ cloud_name }}"
            vip:
            - enabled: true
              vip_id: 0      
              auto_allocate_ip: "true"
              auto_allocate_floating_ip: "{{ configure_dns_vs.allocate_public_ip }}"
              avi_allocated_vip: true
              avi_allocated_fip: "{{ configure_dns_vs.allocate_public_ip }}"
              auto_allocate_ip_type: V4_ONLY
              prefix_length: 32
              ipam_network_subnet:
                network_ref: "{{ dns_vs_subnet.obj.results.0.url }}"
                subnet:
                  ip_addr:
                    addr: "{{ dns_vs_subnet.obj.results.0.ip_subnet.0.prefix.ip_addr.addr }}"
                    type: "{{ dns_vs_subnet.obj.results.0.ip_subnet.0.prefix.ip_addr.type }}"
                  mask: "{{ dns_vs_subnet.obj.results.0.ip_subnet.0.prefix.mask }}"
            dns_info:
            - type: DNS_RECORD_A
              algorithm: DNS_RECORD_RESPONSE_CONSISTENT_HASH
              fqdn: "dns.{{ configure_dns_profile.usable_domains.0 }}"
            name: vsvip-DNS-VS-Default-Cloud
          register: vsvip_results
          until: vsvip_results is not failed
          retries: 30
          delay: 5

        - name: Create DNS Virtual Service
          avi_virtualservice:
            avi_credentials: "{{ avi_credentials }}"
            tenant: "admin"
            name: DNS-VS
            enabled: true
            analytics_policy:
              full_client_logs:
                enabled: true
                duration: 30
              metrics_realtime_update:
                enabled: true
                duration: 30
            traffic_enabled: true
            application_profile_ref: /api/applicationprofile?name=System-DNS
            network_profile_ref: /api/networkprofile?name=System-UDP-Per-Pkt
            analytics_profile_ref: /api/analyticsprofile?name=System-Analytics-Profile
%{ if configure_gslb.enabled && configure_gslb.create_se_group  ~}
            se_group_ref: "{{ gslb_se_group.obj.url }}"
%{ endif ~}
            cloud_ref: "/api/cloud?name={{ cloud_name }}"
            services:
            - port: 53
              port_range_end: 53
            - port: 53
              port_range_end: 53
              override_network_profile_ref: /api/networkprofile/?name=System-TCP-Proxy
            vsvip_ref: "{{ vsvip_results.obj.url }}"
          register: dns_vs
          until: dns_vs is not failed
          retries: 30
          delay: 5

        - name: Add DNS-VS to System Configuration
          avi_systemconfiguration:
            avi_credentials: "{{ avi_credentials }}"
            avi_api_update_method: patch
            avi_api_patch_op: add
            tenant: admin
            dns_virtualservice_refs: "{{ dns_vs.obj.url }}"
      when: configure_dns_vs.enabled == true
      tags: configure_dns_vs

    - name: Configure GSLB
      block:
        - name: GSLB Config | Verify Cluster UUID
          avi_api_session:
            avi_credentials: "{{ avi_credentials }}"
            http_method: get
            path: cluster
          register: cluster
          
        - name: Build list for gslb ip_addresses API field
          set_fact:
            controller_ip_addresses: "{{ controller_ip_addresses | default([]) + [{ 'type': 'V4','addr': ip }] }}"
          loop: "{{ controller_ip }}"
          loop_control:
            loop_var: ip
            index_var: index
          when: index < 3
          
        - name: Build list for dns_configs API field
          set_fact:
            gslb_domains: "{{ gslb_domains | default([]) + [{ 'domain_name': domain }] }}"
          loop: "{{ configure_gslb.domains }}"
          loop_control:
            loop_var: domain
          ignore_errors: yes

        - name: Create GSLB Config
          avi_gslb:
            avi_credentials: "{{ avi_credentials }}"
            name: "GSLB"
            sites:
              - name: "{{ configure_gslb.site_name }}"
                username: "{{ gslb_user }}"
                password: "{{ password }}"
                ip_addresses: "{{ controller_ip_addresses }}"
                enabled: True
                member_type: "GSLB_ACTIVE_MEMBER"
                port: 443
                dns_vses:
                  - dns_vs_uuid: "{{ dns_vs.obj.uuid }}"
                cluster_uuid: "{{ cluster.obj.uuid }}"
            dns_configs: "{{ gslb_domains }}"
            leader_cluster_uuid: "{{ cluster.obj.uuid }}"
          register: gslb_results
      when: configure_gslb.enabled == true and configure_gslb.leader == true
      tags: gslb

    - name: Configure Additional GSLB Sites
      block:
      - name: Include gslb-add-site-tasks.yml in play
        include_tasks: gslb-add-site-tasks.yml
        loop: "{{ configure_gslb.additional_sites }}"
        loop_control:
          loop_var: site
      when: configure_gslb.additional_sites != "null"
      tags:
        - configure_gslb_additional_sites
        - gslb
      ignore_errors: yes

    - name: Controller Cluster Configuration
      avi_cluster:
        avi_credentials: "{{ avi_credentials }}"
        state: present
        #virtual_ip:
        #  type: V4
        #  addr: "{{ controller_cluster_vip }}"
        nodes:
            - name:  "{{ controller_names[0] }}" 
              password: "{{ password }}"
              ip:
                type: V4
                addr: "{{ controller_ip[0] }}"
            - name:  "{{ controller_names[1] }}" 
              password: "{{ password }}"
              ip:
                type: V4
                addr: "{{ controller_ip[1] }}"
            - name:  "{{ controller_names[2] }}" 
              password: "{{ password }}"
              ip:
                type: V4
                addr: "{{ controller_ip[2] }}"
%{ if configure_gslb.enabled ~}
        name: "{{ name_prefix }}-{{ configure_gslb.site_name }}-cluster"
%{ else ~}
        name: "{{ name_prefix }}-cluster"
%{ endif ~}
        tenant_uuid: "admin"
      until: cluster_config is not failed
      retries: 10
      delay: 5
      register: cluster_config
      when: controller_ha == true
      tags: controller_ha

    - name: Add Prerequisites for avi-cloud-services-registration.yml Play
      block:
        - name: Install Avi Collection
          shell: ansible-galaxy collection install vmware.alb -p /home/admin/.ansible/collections

        - name: Copy Ansible module file
          ansible.builtin.copy:
            src: /home/admin/ansible/avi_pulse_registration.py
            dest: /home/admin/.ansible/collections/ansible_collections/vmware/alb/plugins/modules/avi_pulse_registration.py
        
        - name: Remove unused module file
          ansible.builtin.file:
            path: /home/admin/ansible/avi_pulse_registration.py
            state: absent

%{ if split(".", avi_version)[0] == "21" && split(".", avi_version)[2] == "4"  ~}
        - name: Patch file
          shell: patch --directory /opt/avi/python/bin/portal/api/ < /home/admin/ansible/views_albservices.patch
%{ endif ~}
      tags: register_controller
      ignore_errors: true

    - name: Remove patch file
      ansible.builtin.file:
        path: /home/admin/ansible/views_albservices.patch
        state: absent
    
    - name: Remove Cert Keys
      ansible.builtin.replace:
        path: /home/admin/ansible/avi-controller-aws-all-in-one-play.yml
        regexp: '^(\s*)(\"key\":\s+)(.*)$'
        replace: '\1\2""'
      when: ca_certificates.0.certificate != "" or portal_certificate.certificate != "" or securechannel_certificate.certificate != ""

    - name: Remove Certificates
      ansible.builtin.replace:
        path: /home/admin/ansible/avi-controller-aws-all-in-one-play.yml
        regexp: '^(\s*)\s*(-\s+)?\"certificate\":\s+\".*\"$'
        replace: '\1\2"certificate": ""'
      when: ca_certificates.0.certificate != "" or portal_certificate.certificate != "" or securechannel_certificate.certificate != ""

    - name: Verify Cluster State if avi_upgrade or register_controller plays will be ran
      block:
        - name: Pause for 7 minutes for Cluster to form
          ansible.builtin.pause:
            minutes: 7
        
        - name: Wait for Avi Cluster to be ready
          avi_api_session:
            avi_credentials: "{{ avi_credentials }}"
            http_method: get
            path: "cluster/runtime"
          until: cluster_check is not failed
          retries: 60
          delay: 10
          register: cluster_check

        - name: Wait for Avi Cluster to be ready
          avi_api_session:
            avi_credentials: "{{ avi_credentials }}"
            http_method: get
            path: "cluster/runtime"
          until: cluster_runtime.obj.cluster_state.state == "CLUSTER_UP_HA_ACTIVE"
          retries: 60
          delay: 10
          register: cluster_runtime
      when: (controller_ha == true)
      tags: verify_cluster

