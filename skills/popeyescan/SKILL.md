---
name: popeyescan
description: Run a Popeye scan on a Kubernetes/K3s cluster and produce a prioritized analysis. Use this skill whenever the user wants to audit cluster health with Popeye, run popeye, analyze popeye output, triage cluster warnings, check missing probes or resource limits, orphaned services, or review cluster quality score. Also use when the user pastes raw popeye output and asks for analysis, prioritization, or next steps.
---

# Popeye — Scan & Analyse

## Ce que fait cette skill
Lance Popeye sur un cluster K3s/Kubernetes, interprète la sortie, filtre le bruit des faux positifs K3s, et produit un plan d'action priorisé.

---

## Étape 1 — Lancer le scan

**Toujours scanner tous les namespaces.** Sans `-A`, Popeye ne scanne que `default` et rate tous les workloads.

```bash
# Scan complet — tous les namespaces
popeye -A

# Avec contexte explicite (K3s = "default")
popeye -A --context default

# Sauvegarder en JSON pour analyse programmatique
popeye -A --out json --save --output-file /tmp/popeye-report.json

# Sauvegarder en HTML
popeye -A --out html --save --output-file /tmp/popeye-report.html
```

---

## Étape 2 — Légende des sévérités

| Icon | Code | Signification |
|------|------|---------------|
| 💥 | FATAL | Ressource cassée — service sans pods, ingress sans backend |
| 😱 | ERROR | Problème sérieux — pas de limits, restarts, root user, pas de probes |
| 🔊 | WARN  | Bonne pratique — ports non nommés, numéros de port dans ingress |
| ✅ | OK    | Propre |

---

## Étape 3 — Filtrer le bruit (faux positifs K3s)

### Ignorer systématiquement

| Code | Ressource | Raison |
|------|-----------|--------|
| POP-400 | `sh.helm.release.v1.*` secrets | Métadonnées Helm internes, pas des secrets applicatifs |
| POP-1109 | Tous les services | Normal pour déploiements single-replica |
| POP-1204 | Tous les pods | Attendu sur cluster dev/staging sans NetworkPolicies |
| POP-106/107 | flannel, cert-manager, traefik (Helm) | Charts upstream par défaut, pas actionnable |
| POP-302/306 | kube-system (svclb, flannel) | Root requis par design système |
| POP-400 | ClusterRoles `*-cluster-view`, `*-servicebindings` | Roles d'agrégation inutilisés, inoffensifs |
| POP-1300 | `route-controller`, `selinux-warning-controller`, `kube-dns` | ServiceAccounts optionnels non créés par K3s |
| POP-1102 | Tous les services | Cosmétique — ports nommés vs numérotés |

### Toujours escalader

| Code | Signification | Priorité |
|------|---------------|----------|
| POP-1100 💥 | Service sans pods matchant le selector | P1 — workload down |
| POP-1401 💥 | Ingress vers service inexistant | P1 — 404 garanti |
| POP-205 😱 | Pod restart > 5 | P1 — crash loop probable |
| POP-110 😱 | Memory > 200% du request | P1 — risque OOM eviction |
| POP-109 😱 | CPU > 150% du request | P2 — throttling |
| POP-101 😱 | Image `:latest` | P2 — reproductibilité cassée |
| POP-102/103/104 😱 | Pas de probes (tes pods, pas système) | P2 |
| POP-106/107 😱 | Pas de resource limits (tes pods, pas système) | P2 |

---

## Étape 4 — Grille de priorisation

### P1 — Corriger immédiatement
- Services avec `No pods match selector` → app inaccessible
- Ingress pointant vers service inexistant → 404
- Pods en restart loop (> 5 restarts)
- Memory overconsommée > 200% du request

### P2 — Corriger cette semaine (tes workloads applicatifs uniquement)
- Images `:latest`
- Pas de `resources.requests/limits`
- Pas de liveness/readiness probes
- ServiceAccounts avec automount token inutile (POP-301/303)
- Namespace `prospectio` (ou équivalent) avec services orphelins

### P3 — Amélioration continue
- Ports non nommés (POP-108, POP-1403)
- PodDisruptionBudgets manquants (POP-206)
- PV en état `Available` non réclamé (POP-1000)

---

## Étape 5 — Format de réponse attendu

1. **Score global** et interprétation (A=excellent, B=bon, C=acceptable, D/F=problèmes réels)
2. **Problèmes P1** avec ressource exacte `namespace/ressource` + commande kubectl de diagnostic
3. **Problèmes P2** filtrés des composants système — uniquement les workloads applicatifs
4. **Ce qu'on ignore** et pourquoi — expliquer le bruit K3s pour rassurer
5. **Commandes de diagnostic** si restarts ou OOM

```bash
# Diagnostiquer un pod en restart
kubectl logs -n <namespace> deployment/<name> --previous

# Vérifier la consommation mémoire réelle
kubectl top pods -n <namespace>

# Nettoyer un namespace fantôme
kubectl delete namespace <namespace>
```

---

## Spinach.yaml — Supprimer le bruit système durablement

Proposer ce fichier si l'utilisateur veut des scans plus lisibles :

```yaml
# spinach.yaml — à placer à la racine du projet
popeye:
  excludes:
    global:
      - name: rx:kube-system
      - name: rx:kube-flannel
      - name: rx:flux-system
      - name: rx:cert-manager
      - name: rx:external-secrets
      - name: rx:opentelemetry-operator-system
      - name: rx:openobserve-collector
```

```bash
popeye -A --spinach ./spinach.yaml
```