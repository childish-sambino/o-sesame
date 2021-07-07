terraform {
  required_providers {
    twilio = {
      source = "twilio/twilio"
      version = ">=0.4.0"
    }
  }
}

variable "twilio_account_sid" {
  type = string
}
variable "twilio_auth_token" {
  type = string
}
variable "incoming_phone_number" {
  type = string
}
variable "outgoing_phone_number" {
  type = string
}

provider "twilio" {
  account_sid = var.twilio_account_sid
  auth_token = var.twilio_auth_token
}

resource "twilio_api_accounts_incoming_phone_numbers_v2010" "incoming_number" {
  phone_number = var.incoming_phone_number
  voice_url = "https://webhooks.twilio.com/v1/Accounts/${var.twilio_account_sid}/Flows/${twilio_studio_flows_v2.o_sesame_flow.sid}"
  sms_url = "https://webhooks.twilio.com/v1/Accounts/${var.twilio_account_sid}/Flows/${twilio_studio_flows_v2.allow_entry_flow.sid}"
}

resource "twilio_studio_flows_v2" "o_sesame_flow" {
  friendly_name = "O Sesame"
  status = "published"
  definition = jsonencode({
    description: "O Sesame",
    states: [
      {
        name: "Trigger",
        type: "trigger",
        transitions: [
          {
            event: "incomingMessage"
          },
          {
            next: "set_vars",
            event: "incomingCall"
          },
          {
            event: "incomingRequest"
          }
        ],
        properties: {
          offset: {
            x: 70,
            y: 10
          }
        }
      },
      {
        name: "set_vars",
        type: "set-variables",
        transitions: [
          {
            next: "gather_caller",
            event: "next"
          }
        ],
        properties: {
          variables: [
            {
              value: var.twilio_account_sid,
              key: "AccountSid"
            },
            {
              value: var.twilio_auth_token,
              key: "AuthToken"
            },
            {
              value: twilio_studio_flows_v2.allow_entry_flow.sid,
              key: "AllowEntryFlowSid"
            },
            {
              value: var.outgoing_phone_number,
              key: "OutgoingPhoneNumber"
            }
          ],
          offset: {
            x: 90,
            y: 210
          }
        }
      },
      {
        name: "gather_caller",
        type: "gather-input-on-call",
        transitions: [
          {
            next: "gather_caller",
            event: "keypress"
          },
          {
            next: "gather_caller",
            event: "timeout"
          },
          {
            next: "run_subflow",
            event: "speech"
          }
        ],
        properties: {
          voice: "Polly.Matthew-Neural",
          speech_timeout: "auto",
          offset: {
            x: 420,
            y: 210
          },
          loop: 1,
          finish_on_key: "#",
          say: "Hello. Who should I say is calling?",
          language: "en-US",
          stop_gather: false,
          gather_language: "en-US",
          profanity_filter: "true",
          timeout: 5
        }
      },
      {
        name: "run_subflow",
        type: "make-http-request",
        transitions: [
          {
            next: "please_wait",
            event: "success"
          },
          {
            next: "something_wrong",
            event: "failed"
          }
        ],
        properties: {
          offset: {
            x: 250,
            y: 490
          },
          method: "POST",
          content_type: "application/x-www-form-urlencoded;charset=utf-8",
          parameters: [
            {
              value: "{{flow.variables.OutgoingPhoneNumber}}",
              key: "To"
            },
            {
              value: "{{trigger.call.To}}",
              key: "From"
            },
            {
              value: "{\"CallerName\":\"{{widgets.gather_caller.SpeechResult}}\", \"CallSid\": \"{{trigger.call.CallSid}}\"}",
              key: "Parameters"
            }
          ],
          url: "https://{{flow.variables.AccountSid}}:{{flow.variables.AuthToken}}@studio.twilio.com/v2/Flows/{{flow.variables.AllowEntryFlowSid}}/Executions"
        }
      },
      {
        name: "please_wait",
        type: "say-play",
        transitions: [
          {
            next: "enqueue",
            event: "audioComplete"
          }
        ],
        properties: {
          voice: "Polly.Matthew-Neural",
          offset: {
            x: 70,
            y: 780
          },
          loop: 1,
          say: "Please wait.",
          language: "en-US"
        }
      },
      {
        name: "enqueue",
        type: "enqueue-call",
        transitions: [
          {
            event: "callComplete"
          },
          {
            next: "something_wrong",
            event: "failedToEnqueue"
          },
          {
            event: "callFailure"
          }
        ],
        properties: {
          queue_name: "Waiting At Gate",
          offset: {
            x: 220,
            y: 1010
          }
        }
      },
      {
        name: "something_wrong",
        type: "say-play",
        transitions: [
          {
            event: "audioComplete"
          }
        ],
        properties: {
          voice: "Polly.Matthew-Neural",
          offset: {
            x: 500,
            y: 780
          },
          loop: 1,
          say: "I'm sorry. Something went wrong. Please try again later.",
          language: "en-US"
        }
      }
    ],
    initial_state: "Trigger",
    flags: {
      allow_concurrent_calls: true
    }
  })
}

resource "twilio_studio_flows_v2" "allow_entry_flow" {
  friendly_name = "Allow Entry"
  status = "published"
  definition = jsonencode({
    description: "Allow Entry",
    states: [
      {
        name: "Trigger",
        type: "trigger",
        transitions: [
          {
            event: "incomingMessage"
          },
          {
            event: "incomingCall"
          },
          {
            next: "send_and_reply",
            event: "incomingRequest"
          }
        ],
        properties: {
          offset: {
            x: 70,
            y: -110
          }
        }
      },
      {
        name: "set_vars",
        type: "set-variables",
        transitions: [
          {
            next: "send_and_reply",
            event: "next"
          }
        ],
        properties: {
          variables: [
            {
              value: var.twilio_account_sid,
              key: "AccountSid"
            },
            {
              value: var.twilio_auth_token,
              key: "AuthToken"
            }
          ],
          offset: {
            x: 110,
            y: 130
          }
        }
      },
      {
        name: "send_and_reply",
        type: "send-and-wait-for-reply",
        transitions: [
          {
            next: "test",
            event: "incomingMessage"
          },
          {
            next: "hang_up",
            event: "timeout"
          },
          {
            next: "something_wrong",
            event: "deliveryFailure"
          }
        ],
        properties: {
          offset: {
            x: 180,
            y: 380
          },
          from: "{{flow.channel.address}}",
          body: "Someone is at the gate trying to enter: {{flow.data.CallerName}}",
          timeout: "30"
        }
      },
      {
        name: "test",
        type: "split-based-on",
        transitions: [
          {
            next: "hang_up",
            event: "noMatch"
          },
          {
            next: "dial_9",
            event: "match",
            conditions: [
              {
                friendly_name: "If value matches_any_of YES, Yes, yes, Y, y",
                arguments: [
                  "{{widgets.send_and_reply.inbound.Body}}"
                ],
                type: "matches_any_of",
                value: "YES, Yes, yes, Y, y"
              }
            ]
          }
        ],
        properties: {
          input: "{{widgets.send_and_reply.inbound.Body}}",
          offset: {
            x: 130,
            y: 600
          }
        }
      },
      {
        name: "dial_9",
        type: "make-http-request",
        transitions: [
          {
            event: "success"
          },
          {
            event: "failed"
          }
        ],
        properties: {
          offset: {
            x: 280,
            y: 860
          },
          method: "POST",
          content_type: "application/x-www-form-urlencoded;charset=utf-8",
          parameters: [
            {
              value: "<Response><Play digits=\"w9www\"></Play></Response>",
              key: "Twiml"
            }
          ],
          url: "https://{{flow.variables.AccountSid}}:{{flow.variables.AuthToken}}@api.twilio.com/2010-04-01/Accounts/{{flow.variables.AccountSid}}/Calls/{{flow.data.CallSid}}.json"
        }
      },
      {
        name: "hang_up",
        type: "make-http-request",
        transitions: [
          {
            event: "success"
          },
          {
            event: "failed"
          }
        ],
        properties: {
          offset: {
            x: -100,
            y: 860
          },
          method: "POST",
          content_type: "application/x-www-form-urlencoded;charset=utf-8",
          parameters: [
            {
              value: "<Response><Say voice=\"Polly.Matthew-Neural\" language=\"en-US\">I'm sorry. I'm not available right now.</Say></Response>",
              key: "Twiml"
            }
          ],
          url: "https://{{flow.variables.AccountSid}}:{{flow.variables.AuthToken}}@api.twilio.com/2010-04-01/Accounts/{{flow.variables.AccountSid}}/Calls/{{flow.data.CallSid}}.json"
        }
      },
      {
        name: "something_wrong",
        type: "make-http-request",
        transitions: [
          {
            event: "success"
          },
          {
            event: "failed"
          }
        ],
        properties: {
          offset: {
            x: 610,
            y: 600
          },
          method: "POST",
          content_type: "application/x-www-form-urlencoded;charset=utf-8",
          parameters: [
            {
              value: "<Response><Say voice=\"Polly.Matthew-Neural\" language=\"en-US\">I'm sorry. Something went wrong. Please try again later.</Say></Response>",
              key: "Twiml"
            }
          ],
          url: "https://{{flow.variables.AccountSid}}:{{flow.variables.AuthToken}}@api.twilio.com/2010-04-01/Accounts/{{flow.variables.AccountSid}}/Calls/{{flow.data.CallSid}}.json"
        }
      }
    ],
    initial_state: "Trigger",
    flags: {
      allow_concurrent_calls: true
    }
  })
}
