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
  voice_url = "https://webhooks.twilio.com/v1/Accounts/" + var.twilio_account_sid + "/Flows/" + twilio_studio_flows_v2.o_sesame_flow.sid
}

resource "twilio_studio_flows_v2" "o_sesame_flow" {
  friendly_name = "O Sesame"
  status = "published"
  definition = jsonencode({
    description: "A New Flow",
    states: [
      {
        name: "Trigger",
        type: "trigger",
        transitions: [
          {
            event: "incomingMessage"
          },
          {
            next: "gather_caller",
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
        name: "open_gate",
        type: "say-play",
        transitions: [
          {
            event: "audioComplete"
          }
        ],
        properties: {
          offset: {
            x: 20,
            y: 740
          },
          loop: 2,
          digits: "9"
        }
      },
      {
        name: "gather_caller",
        type: "gather-input-on-call",
        transitions: [
          {
            event: "keypress"
          },
          {
            next: "send_message_1",
            event: "speech"
          },
          {
            event: "timeout"
          }
        ],
        properties: {
          voice: "Polly.Matthew-Neural",
          speech_timeout: "auto",
          offset: {
            x: 150,
            y: 220
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
        name: "send_message_1",
        type: "send-message",
        transitions: [
          {
            next: "open_gate",
            event: "sent"
          },
          {
            event: "failed"
          }
        ],
        properties: {
          offset: {
            x: 220,
            y: 510
          },
          service: "{{trigger.message.InstanceSid}}",
          channel: "{{trigger.message.ChannelSid}}",
          from: "{{flow.channel.address}}",
          to: var.outgoing_phone_number,
          body: "Hi {{widgets.gather_caller.SpeechResult}}"
        }
      }
    ],
    initial_state: "Trigger",
    flags: {
      allow_concurrent_calls: true
    }
  })
}
