# Question 3: How many routes are affected if I need to upgrade an Operational Point?

> A Switch needs to be upgraded to support the network

## Introduction

In the [previous question](Question%202.md) we could see that there were situations where we could route around problems, but this isn't always the case. 

In order to know what _Routes_ are affected by an `OperationalPoint` being worked on, we would need to define the concept of a route with reference to the network. 

We don't actually model Routes, what we're modeling is the network itself. Just because you _can_ get from Paddington to Stockholm in a physical sense, it doesn't mean that is a route.

Routes are typically operated by a service provider which could be a private company, or indeed a national government. A _journey_ could take in multiple routes.

To model routes, what could we do?

## Some Ideas

These are a _few_ ideas for how you might want to model it (but you don't _have_ to).

### `ROUTE` Relationship

Add a `ROUTE` relationship to the model.

There are lots of ways to do this, for example we could:

* Have an identifier to say which routes are using this `ROUTE`? 
* Maybe a relationship per route? So some `OperationalPoint`s would be joined by multiple (in the case of big terminals - a *lot*) route relationships.
* Model `ROUTE` only between `Station`/`SmallStation` `OperationalPoints`? - Would this work?
    - If you skip the `Switch` (for example) how would you know it's on the Route? This question would need to be changed to be 'How many routes are affected if I need to upgrade a `Station`.

### Modifying the `SECTION` Relationship

* Maybe just add identifiers to each `SECTION`

## The bigger problem

Where is the data?
This is the biggest issue - there are lots of ways to model the data, and each has pros/cons - but it's largely moot without the data, and this is a good example of how - you can have the best set of reasonable business questions, but you don't have the data to actually achieve it.

It's why you need to ensure that the questions are defined by _all_ the stakeholders, the Project Owners, Business Owners _and_ the Developers - to know if it _even_ is possible. 
