# o-sesame

## Terraform Variables

| Key                   | Value                                             | Default                               |
|-----------------------|---------------------------------------------------|---------------------------------------|
| twilio_account_sid    | Your Twilio Account SID                           |                                       |
| twilio_auth_token     | Your Twilio Account Auth Token                    |                                       |
| incoming_phone_number | Your Twilio-purchased incoming phone number       |                                       |
| outgoing_phone_number | Your personal phone number                        |                                       |
| secret_code           | A secret 4-digit code for opening the gate        |                                       |
| open_commands         | Acceptable response messages for opening the gate | OPEN, Open, open, YES, Yes, yes, Y, y |

_Variables with no default value are required._
