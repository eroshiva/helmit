// Code generated by helmet-generate. DO NOT EDIT.

package v1

import (
	"github.com/onosproject/helmet/pkg/helm/api/resource"
)

type ClusterRoleBindingsClient interface {
	ClusterRoleBindings() ClusterRoleBindingsReader
}

func NewClusterRoleBindingsClient(resources resource.Client, filter resource.Filter) ClusterRoleBindingsClient {
	return &clusterRoleBindingsClient{
		Client: resources,
		filter: filter,
	}
}

type clusterRoleBindingsClient struct {
	resource.Client
	filter resource.Filter
}

func (c *clusterRoleBindingsClient) ClusterRoleBindings() ClusterRoleBindingsReader {
	return NewClusterRoleBindingsReader(c.Client, c.filter)
}