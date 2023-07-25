These questions (and my answers) are part of the proposed challenge.

My steps when executing the challenge are described in the `NOTES.md` file.

These are some of the main references and interesting links I used to research the relevant topics:
- https://nameko.readthedocs.io
	- https://nameko.readthedocs.io/en/stable/what_is_nameko.html
	- https://nameko.readthedocs.io/en/stable/key_concepts.html
	- https://nameko.readthedocs.io/en/stable/dependency_injection_benefits.html#benefits-of-dependency-injection
	- https://nameko.readthedocs.io/en/stable/about_microservices.html
- https://www.coditation.com/blog/how-to-build-microservices-with-nameko
- https://hackernoon.com/building-microservices-with-nameko-part1-ud1135ug
- https://medium.com/nerd-for-tech/introduction-to-python-microservices-with-nameko-435efed35dd5
- https://www.thoughtworks.com/radar/languages-and-frameworks/nameko
- https://github.com/nameko/nameko
	- https://github.com/nameko/nameko/issues/518
- https://ciaranodonnell.dev/posts/message-broker-as-spof/
- https://github.com/search?q=microservices+framework&type=repositories&s=stars&o=desc
- https://www.reddit.com/r/Python/comments/prqzhr/is_nameko_still_worth_using_and_what_to_use/
- https://medium.com/forepaas/microservice-with-nameko-18b919964e3c

## Questions after executing `README-DevEnv.md`

### How does the framework support micro-services architecturally?

A Nameko service is meant to be a simple Python class, exposing its methods primarily over RPC.
This encourages dependency injection and a more clear separation between a service's own code and the rest of the code required for that service to operate.  
The idea of split functionalities with well defined boundaries matches the usual definition of microservices.
It also has the benefit of being scalable, as workloads can be spread across multiple instances of the same service.

### What are the pros and cons? What are the alternatives?

PROs:
- The configuration of a distributed system becomes much easier, which in turn make it simpler for developers to provision local environments
- Attempts to provide a simple API that makes it easy to build and deploy microservices, even for developers who are new to the subject
- Is meant to simplify service discovery, suggesting by default the use of RPC and a messaging broker
- Provides scalability (as mentioned previously) and flexibility (doesn't enforce RPC, allowing the use of other patterns such as Pub-Sub and HTTP)
- Provides good documentation/examples for a quickstart
- Has some community-maintained extensions and packages

CONs:
- May not have currently such a huge adoption, specially when compared to other frameworks
- Confined to Python only  
- Its own documentation states it's not a web framework:
	> [...] it's limited to what is useful in the realm of microservices, [...] to build a webapp for consumption by humans you should use something like flask
- May present some performance overhead due to RPC calls and processes waiting on I/O

Alternatives:
- TODO
	- https://medium.com/microservices-architecture/top-10-microservices-framework-for-2020-eefb5e66d1a2
	- https://www.tatvasoft.com/blog/top-12-microservices-frameworks/
	- https://hackernoon.com/microservices-and-frameworks-all-you-need-to-know

## Questions after using Epinio locally

### What is the framework trying to abstract out?

- TODO

### Does it make it easier for developers/operators when comparing Epinio with native k8s?

- TODO

## Questions after executing `README-DevOps.md` specifically on Epinio

### What are the pros/cons for developers, operators, security etc?

- TODO
