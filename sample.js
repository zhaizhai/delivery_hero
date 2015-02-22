{
    init_restaurants: function(restaurants) {
        window.r = restaurants[0]
    },

    init_cars: function(cars) {
        var car = cars[0];
        car.on('approaching', function(loc) {
            var old_dir = car.direction();
            car.set_next_direction(rotate_right(old_dir));

            if (car.approaching().equals(r.location())) {
                var orders = r.orders();
                for (var i = 0; i < orders.length; i++) {
                    var order = orders[i];
                    if (!order.taken) {
                        car.pickup(order.id);
                        return;
                    }
                }
            }

            if (old_dir === 'up') {
                car.deliver();
            }
        });
    }
}
