# Bootstrap

1. Remember to store the `cilium-ca` secret for the main cluster;
2. Deploy Cilium to the new cluster, with ClusterMesh;

On first run:
- `$ cilium clustermesh connect --context admin@talmox --destination-context admin@hyades`
