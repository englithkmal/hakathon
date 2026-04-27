    <?php $layout->viewContext->mergeIntoNewEnvironment($__env); ?>

    <?php $__env->startComponent($layout->view, $layout->params); ?>
        <?php $__env->slot($layout->slotOrSection); ?>
            <?php echo $content; ?>

        <?php $__env->endSlot(); ?>

        <?php
        // Manually forward slots defined in the Livewire template into the layout component...
        foreach ($layout->viewContext->slots[-1] ?? [] as $name => $slot) {
            $__env->slot($name, attributes: $slot->attributes->getAttributes());
            echo $slot->toHtml();
            $__env->endSlot();
        }
        ?>
    <?php echo $__env->renderComponent(); ?><?php /**PATH C:\Wamp.NET\sites\hakathon\storage\framework\views/f7c29b22c1a51c7cd7168f60bd430f61.blade.php ENDPATH**/ ?>