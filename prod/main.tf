terraform {
  required_providers {
    twilio = {
      source = "twilio/twilio"
      version = "0.11.0"
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
variable "secret_code" {
  type = string
}
variable "open_commands" {
  type = string
  default = "OPEN, Open, open, YES, Yes, yes, Y, y"
}

provider "twilio" {
  username = var.twilio_account_sid
  password = var.twilio_auth_token
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
            event: "incomingRequest"
          },
          {
            event: "incomingParent"
          },
          {
            next: "set_vars",
            event: "incomingCall"
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
            next: "run_alert_flow",
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
            },
            {
              value: var.secret_code,
              key: "SecretCode"
            }
          ],
          offset: {
            x: 140,
            y: 160
          }
        }
      },
      {
        name: "run_alert_flow",
        type: "make-http-request",
        transitions: [
          {
            next: "gather_caller",
            event: "success"
          },
          {
            next: "gather_caller",
            event: "failed"
          }
        ],
        properties: {
          offset: {
            x: 50,
            y: 380
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
              value: "{\"CallSid\": \"{{trigger.call.CallSid}}\"}",
              key: "Parameters"
            }
          ],
          url: "https://{{flow.variables.AccountSid}}:{{flow.variables.AuthToken}}@studio.twilio.com/v2/Flows/{{flow.variables.AllowEntryFlowSid}}/Executions"
        }
      },
      {
        name: "gather_caller",
        type: "gather-input-on-call",
        transitions: [
          {
            next: "test_digits",
            event: "keypress"
          },
          {
            next: "gather_caller",
            event: "timeout"
          },
          {
            next: "please_wait",
            event: "speech"
          }
        ],
        properties: {
          voice: "Polly.Matthew-Neural",
          number_of_digits: 4,
          speech_timeout: "auto",
          offset: {
            x: -80,
            y: 650
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
        name: "please_wait",
        type: "say-play",
        transitions: [
          {
            next: "run_subflow",
            event: "audioComplete"
          }
        ],
        properties: {
          voice: "Polly.Matthew-Neural",
          offset: {
            x: 330,
            y: 940
          },
          loop: 1,
          say: "Please wait.",
          language: "en-US"
        }
      },
      {
        name: "test_digits",
        type: "split-based-on",
        transitions: [
          {
            next: "gather_caller",
            event: "noMatch"
          },
          {
            next: "dial_9",
            event: "match",
            conditions: [
              {
                friendly_name: "If value equal_to SecretCode",
                arguments: [
                  "{{widgets.gather_caller.Digits}}"
                ],
                type: "equal_to",
                value: "{{flow.variables.SecretCode}}"
              }
            ]
          }
        ],
        properties: {
          input: "{{widgets.gather_caller.Digits}}",
          offset: {
            x: 660,
            y: 650
          }
        }
      },
      {
        name: "dial_9",
        type: "say-play",
        transitions: [
          {
            next: "enqueue",
            event: "audioComplete"
          }
        ],
        properties: {
          offset: {
            x: 880,
            y: 1200
          },
          loop: 1,
          digits: "9"
        }
      },
      {
        name: "run_subflow",
        type: "make-http-request",
        transitions: [
          {
            next: "enqueue",
            event: "success"
          },
          {
            next: "please_wait",
            event: "failed"
          }
        ],
        properties: {
          offset: {
            x: 80,
            y: 1200
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
            x: 260,
            y: 1500
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
            x: 490,
            y: 1200
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
            event: "incomingParent"
          },
          {
            next: "set_vars",
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
            next: "split_on_entry",
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
            x: 290,
            y: 130
          }
        }
      },
      {
        name: "split_on_entry",
        type: "split-based-on",
        transitions: [
          {
            next: "entry_message",
            event: "noMatch"
          },
          {
            next: "alert_message",
            event: "match",
            conditions: [
              {
                friendly_name: "{{flow.data.CallerName}}",
                arguments: [
                  "{{flow.data.CallerName}}"
                ],
                type: "is_blank",
                value: "Is Blank"
              }
            ]
          }
        ],
        properties: {
          input: "{{flow.data.CallerName}}",
          offset: {
            x: 180,
            y: 370
          }
        }
      },
      {
        name: "entry_message",
        type: "send-and-wait-for-reply",
        transitions: [
          {
            next: "entry_test",
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
            y: 590
          },
          from: "{{flow.channel.address}}",
          body: "From the gate: {{flow.data.CallerName}}",
          timeout: "30"
        }
      },
      {
        name: "entry_test",
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
                friendly_name: "If value in open commands",
                arguments: [
                  "{{widgets.entry_message.inbound.Body}}"
                ],
                type: "matches_any_of",
                value: var.open_commands
              }
            ]
          }
        ],
        properties: {
          input: "{{widgets.entry_message.inbound.Body}}",
          offset: {
            x: 50,
            y: 840
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
            x: 690,
            y: 1140
          },
          method: "POST",
          content_type: "application/x-www-form-urlencoded;charset=utf-8",
          parameters: [
            {
              value: "<Response><Play digits=\"w9www\"></Play><Enqueue>Waiting At Gate</Enqueue></Response>",
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
            x: -80,
            y: 1100
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
            x: 550,
            y: 840
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
      },
      {
        name: "alert_message",
        type: "send-and-wait-for-reply",
        transitions: [
          {
            next: "alert_test",
            event: "incomingMessage"
          },
          {
            event: "timeout"
          },
          {
            event: "deliveryFailure"
          }
        ],
        properties: {
          offset: {
            x: 620,
            y: 590
          },
          from: "{{flow.channel.address}}",
          body: "Someone is at the gate.",
          timeout: "10"
        }
      },
      {
        name: "alert_test",
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
                friendly_name: "If value in open commands",
                arguments: [
                  "{{widgets.alert_message.inbound.Body}}"
                ],
                type: "matches_any_of",
                value: var.open_commands
              }
            ]
          }
        ],
        properties: {
          input: "{{widgets.alert_message.inbound.Body}}",
          offset: {
            x: 960,
            y: 840
          }
        }
      }
    ],
    initial_state: "Trigger",
    flags: {
      allow_concurrent_calls: true
    }
  })
}
