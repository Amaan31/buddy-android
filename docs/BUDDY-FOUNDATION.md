# SANIA — FOUNDATION

## 1. Project Overview

Sania is a personal AI companion application.

The system is designed around an independent character identity, persistent memory, relationship development, and multi-provider AI support.

Sania must remain consistent even when the underlying AI model changes.

## 2. Core Principles

- Provider-independent personality.
- Independent memory storage.
- Natural and gradual relationship development.
- Independent opinions, boundaries, and agency.
- Secure provider authentication.
- Accessible from multiple devices.
- Modular and extensible architecture.

## 3. Target Architecture

### Client
- Progressive Web App (PWA)
- POCO F6 as primary client
- Browser access from other devices

### Backend
- Conversation Engine
- Persona Engine
- Memory Engine
- Relationship Engine
- Model Router
- Provider Manager
- Authentication Manager

### Storage
- SQLite database
- Conversation history
- Long-term memories
- Persona configuration
- Relationship state
- Encrypted backups

### Hosting
- Initial target: Mi 9 SE
- Remote access through a secure connection

## 4. AI Providers

Initial candidates:

- OpenAI API
- Google Gemini API
- Other compatible providers in the future

Provider integrations must use officially supported authentication and API methods.

A consumer subscription must not be assumed to provide third-party API access.

## 5. Core Modules

### Persona Engine
Manages Sania's identity, personality, communication style, and behavior rules.

### Memory Engine
Stores, retrieves, and manages short-term and long-term memories.

### Relationship Engine
Manages gradual relationship development based on conversation history.

### Conversation Engine
Maintains conversation context and coordinates interactions.

### Model Router
Selects the appropriate AI provider and model.

### Provider Manager
Manages provider configuration, connection status, and supported capabilities.

## 6. Development Roadmap

1. Architecture foundation
2. Database and memory design
3. Character Bible and persona engine
4. Provider integration
5. Conversation engine
6. Model routing
7. PWA interface
8. Remote deployment
9. Testing and evaluation

## 7. Important Constraints

- Sania's biography must be defined by the project owner.
- Do not invent personal identity details.
- Do not copy private conversations verbatim.
- Use anonymized and abstracted communication patterns.
- Do not force affection or relationship milestones.
- Preserve Sania's independent personality.
- Keep credentials out of the frontend.

## 8. Current Status

Project stage: Foundation

Current milestone: Architecture and database design.

No production implementation has been started.
