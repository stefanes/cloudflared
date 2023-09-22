# Cloudflare tunnels with PowerShell

Connect a local Cloudflare tunnel to you network in a few easy steps.

# 1. Setup your domain

Setup your own domain name (e.g. `example.com`) to use the Clodflare nameservers, if you do aready not have one, you can get cheap domains from [Porkbun](https://porkbun.com).

[Add your domain](https://developers.cloudflare.com/fundamentals/setup/account-setup/add-site/#1--add-site-in-cloudflare) to Cloudflare and [update the nameservers](https://kb.porkbun.com/article/22-how-to-change-nameservers) to the ones you received from Cloudflare.

# 2. Download cloudflared

Download and extract `cloudflared` [from Cloudflare](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/tunnel-guide/local/#1-download-and-install-cloudflared).

# 3. Run the script to connect your tunnel

To connect a tunnel routing the default set of services (see [here](https://github.com/stefanes/cloudflared/blob/main/connect-tunnel.ps1#L10-L21)):

```powershell
& .\cloudflared\connect-tunnel.ps1 -CloudflaredPath 'C:\path\to\cloudflared.exe' -HostName 'myhostname.tk'
```

To route other services, provide your own services using the `-DefaultServices` parameter:

```powershell
& .\cloudflared\connect-tunnel.ps1 -CloudflaredPath 'C:\path\to\cloudflared.exe' -HostName 'myhostname.tk' -Service 'http://192.168.2.100:8080' -DefaultServices @(
    @{
        domain  = 'www'
        service = 'http://192.168.2.100:8080'
    }
    @{
        domain  = 'router'
        service = 'http://192.168.2.1'
    }
)
```

Or include additional services (in addition to the default services) using the `-AdditionalServices` parameter:

```powershell
& .\cloudflared\connect-tunnel.ps1 -CloudflaredPath 'C:\path\to\cloudflared.exe' -HostName 'myhostname.tk' -Service 'http://192.168.1.100:8080' -AdditionalServices @(
    @{
        domain  = 'something'
        service = 'http://192.168.1.254'
    }
)
```

# Home Assistant

If using this with Home Assistant you need to do one more thing. Since Home Assistant blocks requests from unknown proxies/reverse proxies, you need to tell your instance to [trust your host network](https://www.home-assistant.io/integrations/http/#trusted_proxies) by adding this to your `configuration.yaml`:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 192.168.1.0/24
```
