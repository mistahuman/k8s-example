package main

import (
	"context"
	"flag"
	"os"

	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
	clientgoscheme "k8s.io/client-go/kubernetes/scheme"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/healthz"
	"sigs.k8s.io/controller-runtime/pkg/log/zap"
	metricsserver "sigs.k8s.io/controller-runtime/pkg/metrics/server"
)

var (
	greetingGVK = schema.GroupVersionKind{
		Group:   "example.com",
		Version: "v1",
		Kind:    "Greeting",
	}
)

type GreetingReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

func (r *GreetingReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := ctrl.LoggerFrom(ctx)

	greeting := &unstructured.Unstructured{}
	greeting.SetGroupVersionKind(greetingGVK)

	if err := r.Get(ctx, req.NamespacedName, greeting); err != nil {
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	message, _, err := unstructured.NestedString(greeting.Object, "spec", "message")
	if err != nil {
		return ctrl.Result{}, err
	}

	observed, _, err := unstructured.NestedString(greeting.Object, "status", "observedMessage")
	if err != nil {
		return ctrl.Result{}, err
	}

	if message == observed {
		return ctrl.Result{}, nil
	}

	if err := unstructured.SetNestedField(greeting.Object, message, "status", "observedMessage"); err != nil {
		return ctrl.Result{}, err
	}

	if err := r.Status().Update(ctx, greeting); err != nil {
		return ctrl.Result{}, err
	}

	logger.Info("updated greeting status", "observedMessage", message)

	return ctrl.Result{}, nil
}

func (r *GreetingReconciler) SetupWithManager(mgr ctrl.Manager) error {
	greeting := &unstructured.Unstructured{}
	greeting.SetGroupVersionKind(greetingGVK)

	return ctrl.NewControllerManagedBy(mgr).
		For(greeting).
		Complete(r)
}

func main() {
	var metricsAddr string
	var probeAddr string

	flag.StringVar(&metricsAddr, "metrics-bind-address", ":8080", "The address the metric endpoint binds to.")
	flag.StringVar(&probeAddr, "health-probe-bind-address", ":8081", "The address the probe endpoint binds to.")
	flag.Parse()

	ctrl.SetLogger(zap.New(zap.UseDevMode(true)))

	scheme := runtime.NewScheme()
	if err := clientgoscheme.AddToScheme(scheme); err != nil {
		ctrl.Log.Error(err, "unable to add client-go scheme")
		os.Exit(1)
	}

	mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
		Scheme:                 scheme,
		Metrics:               metricsserver.Options{BindAddress: metricsAddr},
		HealthProbeBindAddress: probeAddr,
		LeaderElection:         false,
	})
	if err != nil {
		ctrl.Log.Error(err, "unable to start manager")
		os.Exit(1)
	}

	if err := (&GreetingReconciler{
		Client: mgr.GetClient(),
		Scheme: mgr.GetScheme(),
	}).SetupWithManager(mgr); err != nil {
		ctrl.Log.Error(err, "unable to create controller")
		os.Exit(1)
	}

	if err := mgr.AddHealthzCheck("healthz", healthz.Ping); err != nil {
		ctrl.Log.Error(err, "unable to set up health check")
		os.Exit(1)
	}

	if err := mgr.AddReadyzCheck("readyz", healthz.Ping); err != nil {
		ctrl.Log.Error(err, "unable to set up ready check")
		os.Exit(1)
	}

	ctrl.Log.Info("starting manager")
	if err := mgr.Start(ctrl.SetupSignalHandler()); err != nil {
		ctrl.Log.Error(err, "problem running manager")
		os.Exit(1)
	}
}
