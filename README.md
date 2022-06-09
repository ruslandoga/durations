Having a table like

| time       | project |
| ---------- | ------- |
| 1654761510 | w1      |
| 1654761520 | w1      |
| 1654761530 | w2      |
| 1654761539 | w2      |

These functions would produce

| total |
| ----- |
| 29    |

| total | project |
| ----- | ------- |
| 20    | w1      |
| 9     | w2      |

| project | from       | to         |
| ------- | ---------- | ---------- |
| w1      | 1654761510 | 1654761530 |
| w2      | 1654761530 | 1654761539 |

(to be used in a custom aggregate function for sqlite)
