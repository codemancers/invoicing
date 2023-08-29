# Ruby Invoicing Framework
[![Build Status](https://travis-ci.org/code-mancers/invoicing.svg?branch=master)](https://travis-ci.org/code-mancers/invoicing)
[![Code Climate](https://codeclimate.com/github/code-mancers/invoicing.png)](https://codeclimate.com/github/code-mancers/invoicing)

## Description

This is a framework for generating and displaying invoices (ideal for commercial
Rails apps). It allows for flexible business logic; provides tools for tax handling,
commission calculation etc. It aims to be both developer-friendly and
accountant-friendly.

## Documentation

Detailed documentation about `invoicing` gem can be found on:

https://invoicing.c9s.dev/

## Features

1. Store any number of different types of invoice, credit note and payment
   record
2. Represent customer accounts, supplier accounts, and even complicated
   multi-party billing relationships
3. Automatically format currency values beautifully
4. Automatically round currency values to the customary precision for that
   particular currency, e.g. based on the smallest coin in circulation
5. Support any number of different currencies simultaneously
6. Render invoices, account statements etc. into HTML (fully styleable and
   internationalisable)
7. Export into the UBL XML format for sharing data with other systems
8. Provide you with a default Value Added Tax (VAT) implementation, but you
   can also easily plug in your own tax logic
9. Dynamically display tax-inclusive or tax-exclusive prices depending on
   your customer's location and preferences
10. Deal with tax rates or prices changing over time, and automatically
    switch to the new rate at the right moment
11. Efficiently summarise account balances, sales statements etc. under
    arbitrary conditions (e.g. data from one quarter, or payments due at a
    particular date)

## TODOs

1. Slowly move away from `acts-as` model.
2. Multiple taxes can be applied on goodies.
3. Improve documentation for taxes


## Credits

The Ruby invoicing framework originated as part of the website
[Bid for Wine](http://www.bidforwine.co.uk), developed by Patrick Dietrich,
Conrad Irwin, Michael Arnold and Martin Kleppmann for Ept Computing Ltd.
It was extracted from the Bid for Wine codebase and substantially extended
by Martin Kleppmann.

## License

Copyright (c) 2009 Martin Kleppmann, Ept Computing Limited.
Copyright (c) 2014 Codemancers Tech Pvt Ltd

This gem is made publicly available under the terms of the MIT license.
See LICENSE and/or COPYING for details.
