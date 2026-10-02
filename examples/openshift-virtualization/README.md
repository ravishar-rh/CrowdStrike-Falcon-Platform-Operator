# OpenShift Virtualization + CrowdStrike Falcon

Falcon Operator protects **nodes** (RHCOS workers that host VMs). Guest VMs need a **separate** Falcon sensor install inside each VM OS.

## What protects what

| Layer | Component | How |
| --- | --- | --- |
| OpenShift worker / virt host | `FalconNodeSensor` DaemonSet | ACM policy in this repo |
| Admission / K8s API | `FalconAdmission` | ACM policy in this repo |
| Container images | `FalconImageAnalyzer` | ACM policy in this repo |
| Guest VM (Linux/Windows) | Falcon sensor **inside the VM** | Ansible, cloud-init, golden image, or SCCM/Intune |
| Console visibility | Falcon OpenShift Console Plugin | Optional Helm chart (see below) |

Do **not** deploy `FalconContainer` (sidecar) on OpenShift. Use `FalconNodeSensor` for cluster runtime protection.

## Guest VM sensor (recommended)

Use the certified Ansible collection [`crowdstrike.falcon`](https://developer.crowdstrike.com/falcon-sensor/ansible/overview/):

```bash
ansible-galaxy collection install crowdstrike.falcon
```

Example playbook: `ansible-vm-sensor.yml` in this folder.

For cloud-init Linux VMs, see `cloud-init-linux-sensor.yaml` (attach as `cloudInitNoCloud` userData on the VirtualMachine).

## Optional: Falcon OpenShift Console Plugin

Shows CrowdStrike data on Pod and VirtualMachine pages.

1. Create API client with: Hosts Read, Vulnerabilities Read, Falcon Container Image Read.
2. In each namespace you care about:

```bash
oc create secret generic crowdstrike-api -n <namespace> \
  --from-literal=client_id='...' \
  --from-literal=client_secret='...' \
  --from-literal=cloud_region='us-1'
```

3. Install the Helm chart from CrowdStrike (`falcon-openshift-console-plugin`).

## Best practices for virt clusters

- Tag node sensors with `openshift-virtualization` / cluster name for Falcon grouping.
- Ensure VM guest sensors can reach Falcon cloud (or corporate proxy).
- Protect golden images: bake sensor into templates or run Ansible on first boot.
- Keep host `FalconNodeSensor` and guest sensors on supported versions (Operator 1.15.0 expects node sensor >= 7.40).
- For Windows VMs, use the Windows Falcon sensor via Ansible/`crowdstrike.falcon`, not the Linux node DaemonSet.
