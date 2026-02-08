### Changelog

#### Version 2

**Version 2 is not backwards compatible to 1**

| Version    | Changes |
| -------- | ------- |
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