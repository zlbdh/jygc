# Business Workflow Index

## 1. Enterprise onboarding and platform approval

- Main workflow: `web-portal / mobile-a -> backend -> admin-web -> backend -> web-portal / mobile-a`
- Key facts:
  - Platform portal `admin-web` performs approvals.
  - `backend` persists and distributes state.
  - Enterprise clients `web-portal / mobile-a` display results and support subsequent operations.

## 2. Product / service listing and approval

- Main workflow: `web-portal / mobile-b -> backend -> admin-web -> backend -> web-portal / mobile-b / miniapp`
- Key facts:
  - Approvals happen on the platform.
  - The backend is authoritative for business state.
  - `miniapp` will ultimately provide the consumer entry point, but it is currently a prototype repository.

## 3. Order routing and service execution

- Main workflow: `miniapp / web-portal / mobile-b -> backend -> admin-web -> backend -> mobile-a / mobile-b / mobile-c`
- Key facts:
  - `backend` is authoritative for order and work-order state.
  - The platform handles global oversight and some routing.
  - Service execution will extend to `mobile-c`, whose project is not yet established.

## 4. Approval, to-do, and message synchronization

- Main workflow: `web-portal / admin-web -> backend -> mobile-a / mobile-b / mobile-c`
- Key facts:
  - The backend is the main source for to-do items, messages, and state synchronization.
  - Mobile clients consume these items and submit the corresponding actions.

## 5. Refunds, billing, and exports

- Main workflow: `web-portal / admin-web / mobile-a / mobile-b -> backend`
- Key facts:
  - Finance, exports, idempotency, and auditing requirements are concentrated in `backend`.
  - Web and mobile clients primarily handle queries, initiate actions, and display results.
