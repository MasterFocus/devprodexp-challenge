These questions (and my answers) are part of the proposed challenge.

My steps when executing the challenge are described in the `NOTES.md` file.

<hr>

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
- Moleculer (Node.js)
- Micronaut (Java)
- Quarkus (Java)
- Falcon (Python)
- Go Micro / Orb (Go)
- go-zero (Go)

## Questions after using Epinio locally

### What is the framework trying to abstract out?

- Apps are pushed directly to the platform, eliminating the need for complex CD pipelines and k8s YAML files
- Epinio leverages Paketo to build and launch containers "automagically", while still allowing the use of custom images and/or configurations
- Epinio wraps several Kubernetes components in higher-level abstractions
	- Networking and routing is simplified as new deployments automatically generate a URL
	- A "Service" is actually a group of k8s resources bundled up in a Helm chart
	- An "App" can use k8s Secrets from a "Service" by simply binding them

### Does it make it easier for developers/operators when comparing Epinio with native k8s?

In summary, it removes the burden of managing complex relationships between Kubernetes objects. Developers can shift their focus away from dealing with k8s.
Operators can perform less instrusive tweaks by working with high-level abstractions, while not being prevented from looking "under the hood" if necessary.

## Questions after executing `README-DevOps.md` specifically on Epinio

### What are the pros/cons for developers, operators, security etc?

PROs:
- As mentioned above, the abstractions and automations result in less error-prone work

CONs:
- Epinio is still considered in its infancy and other more mature alternatives exist, such as OpenShift
	- As it's not adopted by a large group of users, it lacks community support
	- There aren't many official instructions and real-life examples online to serve as guidance for beginners
- Anyone willing to have a more fine-grained control (eg. for debugging) may have to step over Epinio's abstractions
	- To do so, users need to first learn what Epinio does "under the hood" before tweaking anything

<hr>

References and interesting links I used to research the relevant topics:
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
- https://microservices.io/
- https://medium.com/microservices-architecture/top-10-microservices-framework-for-2020-eefb5e66d1a2
- https://hackernoon.com/microservices-and-frameworks-all-you-need-to-know
- https://www.tatvasoft.com/blog/top-12-microservices-frameworks/
- https://thenewstack.io/dont-pause-your-kubernetes-adoption-paas-it-instead/
- https://www.suse.com/c/rancher_blog/meet-epinio-the-application-development-engine-for-kubernetes/
- https://www.suse.com/c/kubernetes-in-docker-desktop-just-got-easier-with-epinio/
- https://cfsummit2021.sched.com/list/descriptions/
	- https://static.sched.com/hosted_files/cfsummit2021/b7/Better%20Together%20-%20CF%20vs%202021.pdf
