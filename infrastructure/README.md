## Deployment Steps:
<pre>
Step 1: STEADY_STATE  
ALB->Prod Listener(80 port)   ->TargetGroup1(blue)  ->Original taskset  
    ⌙>Test Listener(9000 port)->TargetGroup2(green)  
                        
Step 2: Deploy Replacement taskset and test deployment on ALB:9000  
ALB->Prod Listener(80 port)   ->TargetGroup1(blue) ->Original taskset  
    ⌙>Test Listener(9000 port)->TargetGroup2(green)->Replacement taskset  
                        
Step 3: Flip TargetGroup2(green) to Prod Listener(80 port) and mark it to Primary.
ALB->Prod Listener(80 port)  ->TargetGroup2(green)->Replacement task  
   ⌙>Test Listener(9000 port)->TargetGroup1(blue) ->Original taskset  
                        
Step 4:  Delete Original taskset.
ALB->Prod Listener(80 port)   ->TargetGroup1(green)->Replacement taskset  
    ⌙>Test Listener(9000 port)->TargetGroup2(blue)  
                          
Next deployemt will use TargetGroup2(blue) and follow Step 1 to 4.
</pre>
