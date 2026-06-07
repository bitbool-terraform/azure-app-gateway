### Changelog

#### Version 2

**Version 2 is not backwards compatible to 1**

| Version    | Changes |
| -------- | ------- |
| v2.2.0 | Fixed identity list issues and deprecated `enable_http2` variable.   |
| v2.1.0 | Added custom request headers rewrite.   |
| v2.0.2 | Added trusted root certs capability.   |
| v2.0.1 | Added longer alert threshold option.   |
| v2.0.0  | Major upgrade: certs input via resource/data (mod agnostic to how they are created), most inputs moved to `app_gw` object for better fallbacks, default values gathered to vars. Now, certs are to 1-1 correspondence with listeners, not hostnames (as it was in v1). That enables SAN usage & multiple hostnames/listener. Azure imposes exactly 1 cert per ssl listener, but multiple hostnames.|


#### Version 1
| Version    | Changes |
| -------- | ------- |
| v1.0.5  | Removed per backend pool alerts, only generic per gateway, due to azure bug.   |
| v1.0.4  | Added alerts/sa tagging support.   |
| v1.0.3  | Fixed var names.   |
| v1.0.2  | Added alerts support and sa logging archiving.   |
| v1.0.1  | Added waf block support and custom port name override (rarely useful).   |
| v1.0.0  | First stable, synced with all projects.   |


### Notes
- Certs are named through host[0], due to compatibility, but the suggested way is through listener keys, since there is 1-1 correspondence (listener <-> cert)

 3 Cases:
 1) Use explicit value for connection to backend:
    - Set host_name, this will use the same value for probe_host_name
 2) Use backend target fqdn for connection to backend:
    - Don't set host_name or probe_host_name, this will make pick_host_name_from_backend_address and            pick_host_name_from_backend_http_settings -> true 
 3) Forward whatever the user sends as hostname:
    - This implies that probe host needs to be specified, so set: 
        - pick_host_name_from_backend_address = false
        - probe_host_name = <value for the probe to succeed>