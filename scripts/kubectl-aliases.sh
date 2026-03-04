#!/usr/bin/env bash
set -e

RC="$HOME/.bashrc"

{
  echo ""
  echo "# kubectl aliases (bootcamp)"
  echo "alias kgp='kubectl get pods'"
  echo "alias kgs='kubectl get svc'"
  echo "alias kgd='kubectl get deploy'"
  echo "alias kgn='kubectl get nodes'"
  echo "alias kdp='kubectl describe pod'"
  echo "alias kdelp='kubectl delete pod'"
  echo "alias kaf='kubectl apply -f'"
  echo "alias kdf='kubectl delete -f'"
  echo "alias kl='kubectl logs'"
  echo "alias kex='kubectl exec -it'"
} >> "$RC"

echo "Done. Run: source ~/.bashrc"

# ╔════════════════════════════════════════╗
# ║   Commands to run above script         ║
# ╚════════════════════════════════════════╝
# bash scripts/kubectl-aliases.sh
# source ~/.bashrc