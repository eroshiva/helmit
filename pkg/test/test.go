// SPDX-FileCopyrightText: 2020-present Open Networking Foundation <info@opennetworking.org>
//
// SPDX-License-Identifier: Apache-2.0

package test

import (
	"fmt"
	"github.com/onosproject/helmit/pkg/input"
	"os"
	"reflect"
	"regexp"
	"runtime/debug"
	"testing"
)

// TestingSuite is a suite of tests
type TestingSuite interface{}

// Suite is an identifier interface for test suites
type Suite struct{}

// SetupTestSuite is an interface for setting up a suite of tests
type SetupTestSuite interface {
	SetupTestSuite(c *input.Context) error
}

// SetupTest is an interface for setting up individual tests
type SetupTest interface {
	SetupTest() error
}

// TearDownTestSuite is an interface for tearing down a suite of tests
type TearDownTestSuite interface {
	TearDownTestSuite() error
}

// TearDownTest is an interface for tearing down individual tests
type TearDownTest interface {
	TearDownTest() error
}

// BeforeTest is an interface for executing code before every test
type BeforeTest interface {
	BeforeTest(testName string) error
}

// AfterTest is an interface for executing code after every test
type AfterTest interface {
	AfterTest(testName string) error
}

func failTestOnPanic(t *testing.T) {
	r := recover()
	if r != nil {
		t.Errorf("test panicked: %v\n%s", r, debug.Stack())
		t.FailNow()
	}
}

// RunTests runs a test suite
func RunTests(t *testing.T, suite TestingSuite, request *TestRequest) {
	defer failTestOnPanic(t)

	suiteSetupDone := false

	methodFinder := reflect.TypeOf(suite)
	tests := []testing.InternalTest{}
	for index := 0; index < methodFinder.NumMethod(); index++ {
		method := methodFinder.Method(index)
		ok, err := testFilter(method.Name, request.Tests)
		if err != nil {
			fmt.Fprintf(os.Stderr, "invalid regexp for -m: %s\n", err)
			os.Exit(1)
		}
		if !ok {
			continue
		}
		if !suiteSetupDone {
			if setupTestSuite, ok := suite.(SetupTestSuite); ok {
				if err := setupTestSuite.SetupTestSuite(input.NewContext("", request.Args)); err != nil {
					panic(err)
				}
			}
			defer func() {
				if tearDownTestSuite, ok := suite.(TearDownTestSuite); ok {
					if err := tearDownTestSuite.TearDownTestSuite(); err != nil {
						panic(err)
					}
				}
			}()
			suiteSetupDone = true
		}
		test := testing.InternalTest{
			Name: method.Name,
			F: func(t *testing.T) {
				defer failTestOnPanic(t)

				if setupTestSuite, ok := suite.(SetupTest); ok {
					if err := setupTestSuite.SetupTest(); err != nil {
						panic(err)
					}
				}
				if beforeTestSuite, ok := suite.(BeforeTest); ok {
					if err := beforeTestSuite.BeforeTest(method.Name); err != nil {
						panic(err)
					}
				}
				defer func() {
					if afterTestSuite, ok := suite.(AfterTest); ok {
						if err := afterTestSuite.AfterTest(method.Name); err != nil {
							panic(err)
						}
					}
					if tearDownTestSuite, ok := suite.(TearDownTest); ok {
						if err := tearDownTestSuite.TearDownTest(); err != nil {
							panic(err)
						}
					}
				}()
				method.Func.Call([]reflect.Value{reflect.ValueOf(suite), reflect.ValueOf(t)})
			},
		}
		tests = append(tests, test)
	}
	runTests(t, tests)
}

// runTest runs a test
func runTests(t *testing.T, tests []testing.InternalTest) {
	for _, test := range tests {
		t.Run(test.Name, test.F)
	}
}

// testFilter filters test method names
func testFilter(name string, cases []string) (bool, error) {
	if ok, _ := regexp.MatchString("^Test", name); !ok {
		return false, nil
	}

	if len(cases) == 0 || cases[0] == "" {
		return true, nil
	}

	for _, test := range cases {
		if test == name {
			return true, nil
		}
	}
	return false, nil
}
