// Copyright 2019-present Open Networking Foundation.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package job

import "os"

const namespace = "kube-test"

// Run runs the job
func Run(job *Job) error {
	coordinator := NewCoordinator()
	if err := coordinator.CreateNamespace(); err != nil {
		return err
	}
	status, err := coordinator.RunJob(job)
	if err != nil {
		return err
	}
	os.Exit(status)
	return nil
}

// NewCoordinator returns a new test job coordinator
func NewCoordinator() *Runner {
	return newRunner(namespace, false)
}