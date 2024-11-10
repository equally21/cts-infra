# Navodila za postavitev

## Postavitev infrastrukture

V mapi terraform se nahaja konfiguracija za postavitev. V konfiguraciji `terraform/terraform.tf` je potrebno popraviti id projekta. V to mapo je potrebno dodati javni ssh ključ, ki se bo dodal na vse strežnike in omogočil ssh prijavo v le te. Postavijo se naslednji strežniki:

| Strežnik | Regija          |
|----------|-----------------|
| na       | us-central1     |
| eu       | europe-west4    |
| asia     | asia-east1      |

```bash
# Prijava v google cloud
gcloud auth application-default login

# Postavitev strežnikov
terraform plan
terraform apply -auto-approve
```

Omogoči se povezava od `86.61.45.0/24`, kjer se nahaja ArgoCD strežnik. Omogoči se tudi promet iz vseh IP-jev do strežnikov, kar omogoči dostop do CTS. Nato se kreirajo strežniki in v zadnjem koraku se generira `inventory` datoteka, ki se uporabi za konfiguracijo strežnikov s pomočjo Ansible.

## Konfiguracija infrastrukture

Infrastruktura se konfigurira s pomočjo Ansible. Datoteka `inventory` se generira v prejšnjem koraku. V datoteki je potrebno popraviti le še pot do zasebnega ssh ključa, ki omogoča dostop do strežnikov. Za konfiguracijo je potrebno zagnati naslednje korake:

```bash
# Ta okoljska spremenljivka izklopi preverjanje SSH ključev v ansible. To je uporabno v testnih okoljih za avtomatizacijo povezovanja na nove strežnike brez ročnega potrjevanja njihovih ključev
export ANSIBLE_HOST_KEY_CHECKING=False

# Potrebno je namestit kubernetes paket za python če še ni nameščen
pip3 install kubernetes

# Potrebno je namestit ansible collection za kubernetes. To omogoči avtomatsko dodajanje ArgoCD clusterjev v kubernetes.
ansible-galaxy collection install kubernetes.core

# Zažene se skripta, ki konfigurira vse strežnike. Za pravilno delovanje mora biti prisoten kubeconfig, da lahko Ansible dostopa do kubernetesa, kjer je nameščen ArgoCD
ansible-playbook -i inventory k3s.yaml
```

## Konfiguracija Kubernetes

Vsi kubernetes viri so shranjeni v gitops mapi. Ta mapa vsebuje mapo global, kjer se nahajajo vse datoteke, ki so enake za vse postavitve. Ima pa vsaka kubernetes gruča tudi svojo mapo, kjer se nahajajo viri specifični zanjo. Potrebno je zamenjati imena kubernetes gruč v datoteki `argocd/application-set.yaml`.

V kubernetes je potrebno dodati vse vire, ki se nahajajo v mapi argocd. Nato ArgoCD skrbi za pravilno stanje teh virov in jih avtomatko posodablja. Tako deluje zvezna dostava. Zvezna dostava, narejena z CircleCI, posodobi `deployment` vir v tem repozitoriju in posledično posodobi CTS na vseh strežnikih.

Kubernetes `IngressRoute` viri imajo vpisanje domene s pomočjo nip.io. Potrebno je prilagoditi tudi te datoteke z novimi domenami, ki se bodo prevedle v pravilne ip naslove. Nahajajo se v `gitops/<ime_strežnika>/`