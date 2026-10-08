# Control Repository Architecture

## 1. Overall purpose

`example-product-harness` is the control plane for development across the example product's repositories. It centrally manages requirements, tasks, evaluations, acceptance, and releases.

Business implementation code remains in business repositories. Structured documents, scripts, skills, and MCP blueprints organize those repositories into an executable development workflow.

The control plane has five components:

- `docs/`: concepts, architecture, workflows, and inventories
- `standards/`: gates, governance, and safety rules
- `templates/`: change, design, execution status, verification, release, and postmortem templates
- `.agent/skills/`: workflow skills for the control repository
- `mcp/`: read-only, nonproduction MCP blueprints

## 2. Responsibilities of the seven business repositories

### 2.1 `backend`: backend microservices

- Stack: Spring Cloud example project, Spring Boot, Spring Cloud Alibaba, MyBatis Plus
- Responsibilities: backend capabilities for orders, commerce, finance, property management, senior care, and training
- Key characteristics: microservices, Redis, RabbitMQ, Seata, exports, idempotency, and permissions

### 2.2 `web-portal`: enterprise desktop web portal

- Stack: Vue 3, Vite, Element Plus, Pinia
- Responsibilities: administration interface for enterprise administrators and business operators
- Key characteristics: work-order dispatch, commerce, finance, smart property management, senior care, training center, and system administration

### 2.3 `admin-web`: example product platform administration portal

- Stack: provisionally governed against Vue 3 + Vite + Element Plus, based on current requirements
- Responsibilities: platform-level enterprise approval, service/product approval, order routing, consumer operations, and global oversight
- Key characteristic: platform-wide control, distinct from enterprise administration

### 2.4 `mobile-a`: enterprise mobile app

- Stack: React Native, Expo, TypeScript
- Responsibilities: mobile management tools for enterprise managers, operations staff, and frontline workers
- Key characteristics: to-do items, orders, customers, employees, approvals, and mobile business views

### 2.5 `mobile-b`: merchant mobile app

- Stack: provisionally governed against React Native + TypeScript, based on current requirements
- Responsibilities: merchant operations, product publishing, order processing, and business analytics on mobile
- Key characteristics: store management, product management, merchant orders, and settlement

### 2.6 `mobile-c`: staff mobile app

- Stack: provisionally governed against React Native + TypeScript, based on current requirements
- Responsibilities: frontline workers accepting assignments, scheduling, clocking in, and viewing earnings
- Key characteristics: work-order execution, attendance, earnings transparency, and notifications

### 2.7 `miniapp`: consumer miniapp

- Stack: provisionally governed as a miniapp project with TypeScript/Node supporting tools, based on current requirements
- Responsibilities: a lightweight consumer service entry point
- Key characteristics: miniapp configuration, platform and enterprise modes, and WeChat ecosystem capabilities

## 3. Control repository responsibilities

- Define `change-id` consistently
- Record cross-repository impact analysis
- Record execution status, owners, locks, and worktrees
- Produce repository-level task cards
- Manage golden regression cases
- Consolidate release checklists and rollback instructions
- Document AI execution rules and human review gates
- Design and host the Agent / Workflow / Skill / MCP control plane
- Manage local synchronization, self-checks, and risk matrices for the seven repositories

## 4. Outside the control repository's responsibilities

- Replacing business-repository READMEs
- Storing business application code
- Bypassing local business-repository verification
- Replacing structured documentation with natural-language conversation history

## 5. Repository collaboration model

```text
Request enters the control repository
  -> clone/sync/discover/baseline
  -> brief.md
  -> impact.yaml
  -> execution.yaml
  -> tasks/<repo>.md
  -> Development and self-tests in each business repository
  -> Cross-platform acceptance in the control repository
  -> Release notes in release/*.md
```

## 6. Directory responsibilities

- `repos/`: business-repository metadata and roles
- `docs/`: global architecture, concepts, workflows, command contracts, and inventories
- `standards/`: shared and platform-specific rules
- `templates/`: standard templates
- `changes/`: complete lifecycle records for individual requests
- `evals/`: golden regression suite and automation entry-point plans
- `reports/`: local synchronization, self-check, contract discovery, and baseline verification reports
- `release/`: release packages and rollback instructions
- `.agent/skills/`: workflow skills for the control repository
- `mcp/`: MCP blueprints and integration policies
- `scripts/`: initialization, validation, and workspace inspection scripts
- `docs/cross-repo/`: long-term cross-repository indexes
