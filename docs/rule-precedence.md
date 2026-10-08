# Rule Precedence

## 1. Why precedence is needed

The example product has several rule layers:

- Global rules
- Control-repository rules
- Business-repository rules
- Module rules
- Skill procedures
- Style preferences

Defined precedence makes the controlling rule clear when these layers conflict.

## 2. Shared precedence order

Apply rules in this order:

1. Safety / environment rules
2. Change contract: `brief / impact / execution / design / tasks`
3. Cross-repository architecture and release gates
4. Business-repository rules
5. Module rules / example implementations
6. Skill procedures
7. Style preferences

Interpretation:

- Higher-priority rules override lower-priority rules.
- Skills cannot override repository rules.
- Repository rules cannot override safety or release gates.
- Style preferences never override functional or safety boundaries.

## 3. Conflict resolution

When rules conflict:

1. Identify the layer of each conflicting rule.
2. Follow the higher-priority rule.
3. Do not guess when rules have equal priority.
4. Record the conflict under `Needs confirmation` in `design.md` or `impact.yaml`.
5. Continue implementation or release only after confirmation.

## 4. Rule metadata

Control-repository rule documents use these metadata fields:

- `scope`
- `owner`
- `applies_to`
- `precedence`
- `last_reviewed`
- `source_of_truth`

They answer four questions:

- What does the rule govern?
- Who maintains it?
- Which repositories or workflows does it apply to?
- What precedence does it have when another rule conflicts?

## 5. Scope at this stage

V1 requires:

- Complete metadata for all control-repository rules under `standards/`.
- The control repository maintains only cross-repository rules and gates.
- Existing business-repository rules stay in place, with metadata added gradually.

The control repository maintains indexes and routing rather than copying business-repository facts.
