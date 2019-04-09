The multiline CSV has 5 distinct types:
1. header
2. lineItem
3. tax line
4. line split
5. charge line

* Tax lines and line splits roll up to the line item.
* If a tax line is under a line split the tax line applies only to that line split.
* Charge lines apply to the header
