package {{ .Package.Name }}

import (
    {{- range $name, $group := .Groups }}
    {{ $group.Package.Alias }} {{ $group.Package.Path | quote }}
    {{- end }}
	"github.com/onosproject/helmit/pkg/helm"
    "github.com/onosproject/helmit/pkg/kubernetes/config"
    "github.com/onosproject/helmit/pkg/kubernetes/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/kubernetes"
	helmkube "helm.sh/helm/v3/pkg/kube"
)

// New returns a new Kubernetes client for the current namespace
func New() (Client, error) {
	return NewForNamespace(config.GetNamespaceFromEnv())
}

// NewOrDie returns a new Kubernetes client for the current namespace
func NewOrDie() Client {
	client, err := New()
	if err != nil {
		panic(err)
	}
	return client
}

// NewForNamespace returns a new Kubernetes client for the given namespace
func NewForNamespace(namespace string) (Client, error) {
	kubernetesConfig, err := config.GetRestConfig()
	if err != nil {
		return nil, err
	}
	kubernetesClient, err := kubernetes.NewForConfig(kubernetesConfig)
	if err != nil {
    	return nil, err
	}
    return &{{ .Types.Struct }}{
        namespace: namespace,
        config:    kubernetesConfig,
        client:    kubernetesClient,
        filter:    resource.NoFilter,
    }, nil
}

// NewForNamespaceOrDie returns a new Kubernetes client for the given namespace
func NewForNamespaceOrDie(namespace string) Client {
	client, err := NewForNamespace(namespace)
	if err != nil {
		panic(err)
	}
	return client
}

// {{ .Types.Interface }} is a Kubernetes client
type {{ .Types.Interface }} interface {
	// Namespace returns the client namespace
	Namespace() string

	// Config returns the Kubernetes REST client configuration
	Config() *rest.Config

	// Clientset returns the client's Clientset
	Clientset() *kubernetes.Clientset

    {{- range $name, $group := .Groups }}
    {{ $group.Names.Proper }}() {{ $group.Package.Alias }}.{{ $group.Types.Interface }}
    {{- end }}
}

// NewForRelease returns a new Kubernetes client for the given release
func NewForRelease(release *helm.HelmRelease) ({{ .Types.Interface }}, error) {
	kubernetesConfig, err := config.GetRestConfig()
	if err != nil {
		return nil, err
	}
	kubernetesClient, err := kubernetes.NewForConfig(kubernetesConfig)
	if err != nil {
    	return nil, err
	}
	parentClient := &{{ .Types.Struct }}{
        namespace: release.Namespace(),
        config:    kubernetesConfig,
        client:    kubernetesClient,
        filter:    resource.NoFilter,
    }
    return &{{ .Types.Struct }}{
        namespace: release.Namespace(),
        config:    kubernetesConfig,
        client:    kubernetesClient,
        filter:    newReleaseFilter(parentClient, release),
    }, nil
}

// NewForReleaseOrDie returns a new Kubernetes client for the given release
func NewForReleaseOrDie(release *helm.HelmRelease) {{ .Types.Interface }} {
    client, err := NewForRelease(release)
    if err != nil {
        panic(err)
    }
    return client
}

func newReleaseFilter(client resource.Client, release *helm.HelmRelease) resource.Filter {
    return func(kind metav1.GroupVersionKind, meta metav1.ObjectMeta) (bool, error) {
        resources, err := release.GetResources()
        if err != nil {
            return false, err
        }
        for _, resource := range resources {
            resourceKind := resource.Object.GetObjectKind().GroupVersionKind()
            if resourceKind.Group == kind.Group &&
                resourceKind.Version == kind.Version &&
                resourceKind.Kind == kind.Kind &&
                resource.Namespace == meta.Namespace &&
                resource.Name == meta.Name {
                return true, nil
            }
        }
        return filterOwnerReferences(client, resources, kind, meta)
    }
}

func filterOwnerReferences(client resource.Client, resources helmkube.ResourceList, kind metav1.GroupVersionKind, meta metav1.ObjectMeta) (bool, error) {
    for _, owner := range meta.OwnerReferences {
        for _, resource := range resources {
            resourceKind := resource.Object.GetObjectKind().GroupVersionKind()
            if resourceKind.Kind == owner.Kind &&
                resourceKind.GroupVersion().String() == owner.APIVersion &&
                resource.Name == owner.Name {
                return true, nil
            }
        }

        {{- range $groupName, $group := .Groups }}
        {{- range $resourceName, $resource := $group.Resources }}
        if owner.APIVersion == {{ (printf "%s.%s" $resource.Group.Group $resource.Group.Version) | quote }} {
            filter := {{ $resource.Resource.Package.Alias }}.{{ $resource.Filter.Types.Func }}(client, func(kind metav1.GroupVersionKind, meta metav1.ObjectMeta) (bool, error) {
                return filterOwnerReferences(client, resources, kind, meta)
            })
            ok, err := filter(kind, meta)
            if ok {
                return true, nil
            } else if err != nil {
                return false, err
            }
        }
        {{- end }}
        {{- end }}
    }
    return false, nil
}

type {{ .Types.Struct }} struct {
	namespace string
	config    *rest.Config
	client    *kubernetes.Clientset
	filter    resource.Filter
}

func (c *{{ .Types.Struct }}) Namespace() string {
	return c.namespace
}

func (c *{{ .Types.Struct }}) Config() *rest.Config {
	return c.config
}

func (c *{{ .Types.Struct }}) Clientset() *kubernetes.Clientset {
	return c.client
}

{{- range $name, $group := .Groups }}
func (c *{{ .Types.Struct }}) {{ $group.Names.Proper }}() {{ $group.Package.Alias }}.{{ $group.Types.Interface }} {
    return {{ $group.Package.Alias }}.New{{ $group.Types.Interface }}(c, c.filter)
}
{{ end }}
