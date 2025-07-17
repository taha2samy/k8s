
locals {
  worker = {
    autoscale = {
      min_vcpu_count    = 2
      max_vcpu_count    = 3
      min_memory_mib    = 4096
      max_memory_mib    = 6144
      burstable_performance = "included"
    }
  }
}
