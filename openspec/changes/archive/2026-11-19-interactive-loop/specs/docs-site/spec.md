# Spec Delta

## MODIFIED Requirements

### Requirement: The update and view loop can be tried in the page
The site SHALL include an interactive component on the concepts page for the update and view loop in which the reader sends messages, steps a message through the loop one step at a time, selects any step to see what it does and, for the steps that are the reader's own code, the code that implements it, and sees the resulting state and frame. The component SHALL state that it is an illustration and link to the runnable example.

#### Scenario: The reader sends a message
- **WHEN** a reader triggers a message in the component
- **THEN** the displayed state and frame change as the loop would change them

#### Scenario: Stepping a message through the loop
- **WHEN** a reader sends a message and steps through it
- **THEN** each step of the loop is highlighted in the order a message takes through it, the state changes at the step where update runs, and the frame changes at the last step

#### Scenario: Inspecting a step
- **WHEN** a reader selects a step of the loop
- **THEN** the component shows what the step does, and for update and view it shows the code from the compiled counter example

#### Scenario: Using only the keyboard
- **WHEN** a reader uses only the keyboard
- **THEN** the controls for sending a message, stepping, and selecting a step are all reachable and operable, and the current step is announced to assistive technology

#### Scenario: Reduced motion
- **WHEN** the reader's system asks for reduced motion
- **THEN** nothing in the component moves and it does not play through on its own

#### Scenario: Scripts disabled
- **WHEN** the page is opened with scripts disabled
- **THEN** a written breakdown of every step of the loop, with the same explanations and the same code, is visible
