# cloudflared

Connect a local Cloudflare tunnel to you network in a few easy steps.

# 1. Setup your domain

Setup your own domain name (e.g. example.com) and use the Clodflare nameservers. If you do not have one, you can get one for free at [Freenom](https://www.freenom.com/en/index.html?lang=en) following e.g. [this article](https://www.linkedin.com/pulse/what-do-domain-name-how-get-one-free-tobias-brenner?trk=public_post-content_share-article).

# 2. Download cloudflared

Download and extract `cloudflared` [from Cloudflare](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/tunnel-guide/local/#1-download-and-install-cloudflared).

# 3. Run the script to connect your tunnel

To connect a tunnel routing the default set of services (see [here](https://github.com/stefanes/cloudflared/blob/main/connect-tunnel.ps1#L6-L14)):

```powershell
& .\cloudflared\connect-tunnel.ps1 -CloudflaredPath 'C:\path\to\cloudflared.exe' -HostName 'myhostname.tk'
```

To route other services, provide the `-AdditionalServices` parameter:

```powershell
& .\cloudflared\connect-tunnel.ps1 -CloudflaredPath 'C:\path\to\cloudflared.exe' -HostName 'myhostname.tk' -Service 'http://192.168.1.100:8080' -AdditionalServices @(
    @{
        domain  = 'www'
        service = 'http://192.168.1.100:8080'
    }
    @{
        domain  = 'something'
        service = 'http://192.168.1.254'
    }
)
```
