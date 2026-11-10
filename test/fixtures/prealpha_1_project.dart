/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

/// Fixed prealpha.1 project containing a track, a pattern, and a note.
///
/// Kept as JSON so current model changes cannot alter the migration input.
const prealpha1ProjectJson = r'''
{
  "sequence": {
    "nextNoteId": 1,
    "nextClipId": 0,
    "ticksPerQuarter": 96,
    "beatsPerMinuteRaw": 13700,
    "patterns": {
      "16": {
        "id": 16,
        "name": "Persistence melody",
        "clipAutoSizeMode": "nextBar",
        "notes": {
          "0": {
            "id": 0,
            "key": 67,
            "velocity": 0.75,
            "length": 72,
            "offset": 48,
            "pan": -0.125
          }
        },
        "automation": {
          "points": []
        },
        "timeSignatureChanges": []
      }
    },
    "defaultTimeSignature": {
      "numerator": 4,
      "denominator": 4
    },
    "arrangements": {
      "0": {
        "id": 0,
        "name": "Arrangement 1",
        "clips": {},
        "timeSignatureChanges": []
      }
    },
    "arrangementOrder": [
      0
    ]
  },
  "processingGraph": {
    "nodes": {
      "1": {
        "id": 1,
        "audioInputPorts": [
          {
            "id": 0,
            "nodeId": 1,
            "config": {
              "dataType": "audio"
            },
            "connections": [
              15
            ]
          }
        ],
        "eventInputPorts": [],
        "controlInputPorts": [],
        "audioOutputPorts": [],
        "eventOutputPorts": [],
        "controlOutputPorts": [],
        "isThirdPartyPlugin": false,
        "processor": {
          "MasterOutputProcessorModel": {
            "nodeId": 1
          }
        },
        "processorState": ""
      },
      "4": {
        "id": 4,
        "audioInputPorts": [
          {
            "id": 0,
            "nodeId": 4,
            "config": {
              "dataType": "audio"
            },
            "connections": []
          }
        ],
        "eventInputPorts": [],
        "controlInputPorts": [
          {
            "id": 2,
            "nodeId": 4,
            "config": {
              "dataType": "control",
              "parameterConfig": {
                "id": 2,
                "displayMode": "gainDb",
                "unitLabel": "dB",
                "defaultValue": 0.65625,
                "normalizedVisualBaseline": 0.25
              }
            },
            "connections": [],
            "parameterValue": 0.321
          },
          {
            "id": 3,
            "nodeId": 4,
            "config": {
              "dataType": "control",
              "parameterConfig": {
                "id": 3,
                "displayMode": "pan",
                "defaultValue": 0.5,
                "normalizedVisualBaseline": 0.5
              }
            },
            "connections": [],
            "parameterValue": 0.5
          }
        ],
        "audioOutputPorts": [
          {
            "id": 1,
            "nodeId": 4,
            "config": {
              "dataType": "audio"
            },
            "connections": [
              6,
              14
            ]
          }
        ],
        "eventOutputPorts": [],
        "controlOutputPorts": [],
        "isThirdPartyPlugin": false,
        "owner": {
          "trackId": 2
        },
        "processor": {
          "UtilityProcessorModel": {
            "nodeId": 4
          }
        },
        "processorState": ""
      },
      "5": {
        "id": 5,
        "audioInputPorts": [
          {
            "id": 0,
            "nodeId": 5,
            "config": {
              "dataType": "audio"
            },
            "connections": [
              6
            ]
          }
        ],
        "eventInputPorts": [],
        "controlInputPorts": [],
        "audioOutputPorts": [],
        "eventOutputPorts": [],
        "controlOutputPorts": [],
        "isThirdPartyPlugin": false,
        "owner": {
          "trackId": 2
        },
        "processor": {
          "DbMeterProcessorModel": {
            "nodeId": 5,
            "publishEverySamples": 1024,
            "visualizationIds": [
              "db-meter-2-left",
              "db-meter-2-right"
            ]
          }
        },
        "processorState": ""
      },
      "7": {
        "id": 7,
        "audioInputPorts": [],
        "eventInputPorts": [],
        "controlInputPorts": [],
        "audioOutputPorts": [],
        "eventOutputPorts": [
          {
            "id": 0,
            "nodeId": 7,
            "config": {
              "dataType": "event"
            },
            "connections": []
          }
        ],
        "controlOutputPorts": [],
        "isThirdPartyPlugin": false,
        "owner": {
          "trackId": 2
        },
        "processor": {
          "SequenceNoteProviderProcessorModel": {
            "nodeId": 7,
            "trackId": 2
          }
        },
        "processorState": ""
      },
      "8": {
        "id": 8,
        "audioInputPorts": [],
        "eventInputPorts": [],
        "controlInputPorts": [],
        "audioOutputPorts": [],
        "eventOutputPorts": [
          {
            "id": 0,
            "nodeId": 8,
            "config": {
              "dataType": "event"
            },
            "connections": []
          }
        ],
        "controlOutputPorts": [],
        "isThirdPartyPlugin": false,
        "owner": {
          "trackId": 2
        },
        "processor": {
          "LiveEventProviderProcessorModel": {
            "nodeId": 8
          }
        },
        "processorState": ""
      },
      "9": {
        "id": 9,
        "audioInputPorts": [
          {
            "id": 0,
            "nodeId": 9,
            "config": {
              "dataType": "audio"
            },
            "connections": [
              14
            ]
          }
        ],
        "eventInputPorts": [],
        "controlInputPorts": [
          {
            "id": 2,
            "nodeId": 9,
            "config": {
              "dataType": "control",
              "parameterConfig": {
                "id": 2,
                "displayMode": "gainDb",
                "unitLabel": "dB",
                "defaultValue": 0.8125,
                "normalizedVisualBaseline": 0.0
              }
            },
            "connections": [],
            "parameterValue": 0.8125
          },
          {
            "id": 3,
            "nodeId": 9,
            "config": {
              "dataType": "control",
              "parameterConfig": {
                "id": 3,
                "displayMode": "pan",
                "defaultValue": 0.5,
                "normalizedVisualBaseline": 0.5
              }
            },
            "connections": [],
            "parameterValue": 0.5
          }
        ],
        "audioOutputPorts": [
          {
            "id": 1,
            "nodeId": 9,
            "config": {
              "dataType": "audio"
            },
            "connections": [
              11,
              15
            ]
          }
        ],
        "eventOutputPorts": [],
        "controlOutputPorts": [],
        "isThirdPartyPlugin": false,
        "owner": {
          "trackId": 3
        },
        "processor": {
          "UtilityProcessorModel": {
            "nodeId": 9
          }
        },
        "processorState": ""
      },
      "10": {
        "id": 10,
        "audioInputPorts": [
          {
            "id": 0,
            "nodeId": 10,
            "config": {
              "dataType": "audio"
            },
            "connections": [
              11
            ]
          }
        ],
        "eventInputPorts": [],
        "controlInputPorts": [],
        "audioOutputPorts": [],
        "eventOutputPorts": [],
        "controlOutputPorts": [],
        "isThirdPartyPlugin": false,
        "owner": {
          "trackId": 3
        },
        "processor": {
          "DbMeterProcessorModel": {
            "nodeId": 10,
            "publishEverySamples": 1024,
            "visualizationIds": [
              "db-meter-3-left",
              "db-meter-3-right"
            ]
          }
        },
        "processorState": ""
      },
      "12": {
        "id": 12,
        "audioInputPorts": [],
        "eventInputPorts": [],
        "controlInputPorts": [],
        "audioOutputPorts": [],
        "eventOutputPorts": [
          {
            "id": 0,
            "nodeId": 12,
            "config": {
              "dataType": "event"
            },
            "connections": []
          }
        ],
        "controlOutputPorts": [],
        "isThirdPartyPlugin": false,
        "owner": {
          "trackId": 3
        },
        "processor": {
          "SequenceNoteProviderProcessorModel": {
            "nodeId": 12,
            "trackId": 3
          }
        },
        "processorState": ""
      },
      "13": {
        "id": 13,
        "audioInputPorts": [],
        "eventInputPorts": [],
        "controlInputPorts": [],
        "audioOutputPorts": [],
        "eventOutputPorts": [
          {
            "id": 0,
            "nodeId": 13,
            "config": {
              "dataType": "event"
            },
            "connections": []
          }
        ],
        "controlOutputPorts": [],
        "isThirdPartyPlugin": false,
        "owner": {
          "trackId": 3
        },
        "processor": {
          "LiveEventProviderProcessorModel": {
            "nodeId": 13
          }
        },
        "processorState": ""
      }
    },
    "connections": {
      "6": {
        "id": 6,
        "sourceNodeId": 4,
        "sourcePortId": 1,
        "destinationNodeId": 5,
        "destinationPortId": 0,
        "dataType": "audio"
      },
      "11": {
        "id": 11,
        "sourceNodeId": 9,
        "sourcePortId": 1,
        "destinationNodeId": 10,
        "destinationPortId": 0,
        "dataType": "audio"
      },
      "14": {
        "id": 14,
        "sourceNodeId": 4,
        "sourcePortId": 1,
        "destinationNodeId": 9,
        "destinationPortId": 0,
        "dataType": "audio"
      },
      "15": {
        "id": 15,
        "sourceNodeId": 9,
        "sourcePortId": 1,
        "destinationNodeId": 1,
        "destinationPortId": 0,
        "dataType": "audio"
      }
    },
    "masterOutputNodeId": 1
  },
  "savedInSoftwareVersion": "0.0.0-prealpha.1",
  "tracks": {
    "2": {
      "id": 2,
      "name": "Persistence track",
      "color": {
        "hue": 0.0,
        "palette": "grayscale"
      },
      "type": "normal",
      "childTracks": [],
      "automationLanes": [],
      "isMasterTrack": false,
      "processing": {
        "utilityNodeId": 4,
        "dbMeterNodeId": 5,
        "devices": [],
        "deviceRoutingConnectionIds": [],
        "sequenceNoteProviderNodeId": 7,
        "liveEventProviderNodeId": 8
      }
    },
    "3": {
      "id": 3,
      "name": "Master",
      "color": {
        "hue": 0.0,
        "palette": "grayscale"
      },
      "type": "normal",
      "childTracks": [],
      "automationLanes": [],
      "isMasterTrack": true,
      "processing": {
        "utilityNodeId": 9,
        "dbMeterNodeId": 10,
        "devices": [],
        "deviceRoutingConnectionIds": [],
        "sequenceNoteProviderNodeId": 12,
        "liveEventProviderNodeId": 13
      }
    }
  },
  "trackOrder": [
    2
  ],
  "sendTrackOrder": [
    3
  ],
  "idCounter": 17,
  "id": "11111111-1111-4111-8111-111111111111"
}
''';
